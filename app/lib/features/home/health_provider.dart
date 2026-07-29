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
final stepsSupportedProvider = StateProvider<bool>((ref) => true); // Track whether watch hardware has Pedometer


class HealthNotifier extends StateNotifier<HealthReading> {
  HealthNotifier() : super(HealthReading.empty);

  final _api = ApiService();
  Timer? _syncTimer;
  final _ws = WebSocketService();
  int _baseSteps = 0;

  /// Captures pre-existing app step count when watch connects so live watch steps accumulate on top of baseline
  void syncWatchBaseline() {
    _baseSteps = state.steps;
  }

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
        final int? newSteps = (data['steps'] as num?)?.toInt();
        final double? newLat = (data['coordinates']?['lat'] as num?)?.toDouble();
        final double? newLng = (data['coordinates']?['lng'] as num?)?.toDouble();

        // For steps: backend data only wins if higher than current live BLE data.
        // This prevents stale backend data from overwriting real-time BLE step count.
        final int resolvedSteps = (newSteps != null && newSteps > state.steps)
            ? newSteps
            : state.steps;

        if (newSteps != null && newSteps > _baseSteps) {
          _baseSteps = newSteps;
        }

        state = HealthReading(
          heartRate: (newHr != null && newHr > 0) ? newHr : state.heartRate,
          systolic: (newSys != null && newSys > 0) ? newSys : state.systolic,
          diastolic: (newDia != null && newDia > 0) ? newDia : state.diastolic,
          steps: resolvedSteps,
          lat: (newLat != null) ? newLat : state.lat,
          lng: (newLng != null) ? newLng : state.lng,
        );

      }
    } catch (_) {}
  }

  /// Smart Telemetry Merging:
  /// Never overwrite valid calculated measurements with transient 0 values sent during calculation.
  /// For steps: accumulate live watch steps on top of pre-existing app baseline steps.
  void updateFromWatch(Map<String, dynamic> data) {
    final hr = data['heartRate'] ?? data['bpm'];
    final sys = data['systolic'] ?? data['sys'];
    final dia = data['diastolic'] ?? data['dia'];
    final st = data['steps'];
    final lat = data['coordinates']?['lat'] ?? data['lat'];
    final lng = data['coordinates']?['lng'] ?? data['lng'];

    final double validHr = (hr != null && (hr as num) > 0) ? hr.toDouble() : state.heartRate;
    final double validSys = (sys != null && (sys as num) > 0) ? sys.toDouble() : state.systolic;
    final double validDia = (dia != null && (dia as num) > 0) ? dia.toDouble() : state.diastolic;
    
    int validSteps = state.steps;
    if (st != null) {
      final int rawWatchSteps = (st as num).toInt();
      if (rawWatchSteps >= 0) {
        final int accumulated = _baseSteps + rawWatchSteps;
        validSteps = rawWatchSteps > accumulated ? rawWatchSteps : accumulated;
      }
    }

    final double? validLat = (lat != null) ? (lat as num).toDouble() : state.lat;
    final double? validLng = (lng != null) ? (lng as num).toDouble() : state.lng;

    state = HealthReading(
      heartRate: validHr,
      systolic: validSys,
      diastolic: validDia,
      steps: validSteps,
      lat: validLat,
      lng: validLng,
    );
  }


  void reset() {
    stopContinuousSync();
    _baseSteps = 0;
    state = HealthReading.empty;
  }

  /// Only clears health data display - does NOT stop sync timers or WebSocket
  void clearData() {
    _baseSteps = 0;
    state = HealthReading.empty;
  }
}
