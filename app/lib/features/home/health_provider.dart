import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/websocket_service.dart';
import '../../shared/models/models.dart';

final healthProvider = StateNotifierProvider<HealthNotifier, HealthReading>((ref) {
  final notifier = HealthNotifier();
  // Fetch latest stored calculated telemetry on startup
  notifier.fetchLatestDataFromBackend();
  return notifier;
});

final watchConnectedProvider = StateProvider<bool>((ref) => false);
final hrSupportedProvider = StateProvider<bool>((ref) => true);    // Track whether watch hardware has HR sensor
final bpSupportedProvider = StateProvider<bool>((ref) => true);    // Track whether watch hardware has BP sensor
final spo2SupportedProvider = StateProvider<bool>((ref) => true);  // Track whether watch hardware has SpO2 sensor
final stepsSupportedProvider = StateProvider<bool>((ref) => true); // Track whether watch hardware has Pedometer

class HealthNotifier extends StateNotifier<HealthReading> {
  HealthNotifier() : super(HealthReading.empty);

  final _api = ApiService();
  Timer? _syncTimer;
  final _ws = WebSocketService();

  void startContinuousSync() {
    // 1. Load latest calculated stored data first
    fetchLatestDataFromBackend();

    // 2. Connect WebSocket for live push
    _ws.connect(onDataReceived: (data) {
      updateFromWatch(data);
    });

    // 3. 3-second backend sync for newly calculated readings
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchLatestDataFromBackend();
    });
  }

  void stopContinuousSync() {
    _syncTimer?.cancel();
    _ws.disconnect();
  }

  Future<void> fetchLatestDataFromBackend() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final res = await _api.get(ApiConstants.todayData(uid));
      if (res['data'] != null) {
        final data = res['data'];
        final double? newHr = (data['heartRate'] as num?)?.toDouble();
        final double? newSys = (data['systolic'] as num?)?.toDouble();
        final double? newDia = (data['diastolic'] as num?)?.toDouble();
        final double? newSpo2 = (data['spo2'] as num?)?.toDouble();
        final int? newSteps = (data['steps'] as num?)?.toInt();
        final double? newLat = (data['coordinates']?['lat'] as num?)?.toDouble();
        final double? newLng = (data['coordinates']?['lng'] as num?)?.toDouble();

        // Preserve latest non-zero calculated values
        state = HealthReading(
          heartRate: (newHr != null && newHr > 0) ? newHr : state.heartRate,
          systolic: (newSys != null && newSys > 0) ? newSys : state.systolic,
          diastolic: (newDia != null && newDia > 0) ? newDia : state.diastolic,
          spo2: (newSpo2 != null && newSpo2 > 0) ? newSpo2 : state.spo2,
          steps: (newSteps != null && newSteps > 0) ? newSteps : state.steps,
          lat: (newLat != null) ? newLat : state.lat,
          lng: (newLng != null) ? newLng : state.lng,
        );
      }
    } catch (_) {}
  }

  /// Smart Telemetry Merging:
  /// Never overwrite valid calculated measurements with transient 0 values sent during calculation.
  void updateFromWatch(Map<String, dynamic> data) {
    final hr = data['heartRate'] ?? data['bpm'];
    final sys = data['systolic'] ?? data['sys'];
    final dia = data['diastolic'] ?? data['dia'];
    final ox = data['spo2'] ?? data['oxygen'] ?? data['bloodOxygen'];
    final st = data['steps'];
    final lat = data['coordinates']?['lat'] ?? data['lat'];
    final lng = data['coordinates']?['lng'] ?? data['lng'];

    final double validHr = (hr != null && (hr as num) > 0) ? hr.toDouble() : state.heartRate;
    final double validSys = (sys != null && (sys as num) > 0) ? sys.toDouble() : state.systolic;
    final double validDia = (dia != null && (dia as num) > 0) ? dia.toDouble() : state.diastolic;
    final double validSpo2 = (ox != null && (ox as num) > 0) ? ox.toDouble() : state.spo2;
    final int validSteps = (st != null && (st as num) > 0) ? st.toInt() : state.steps;
    final double? validLat = (lat != null) ? (lat as num).toDouble() : state.lat;
    final double? validLng = (lng != null) ? (lng as num).toDouble() : state.lng;

    state = HealthReading(
      heartRate: validHr,
      systolic: validSys,
      diastolic: validDia,
      spo2: validSpo2,
      steps: validSteps,
      lat: validLat,
      lng: validLng,
    );
  }

  void reset() {
    stopContinuousSync();
    state = HealthReading.empty;
  }
}
