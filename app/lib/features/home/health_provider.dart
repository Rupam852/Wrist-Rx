import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/websocket_service.dart';
import '../../core/services/pedometer_service.dart';
import '../../shared/models/models.dart';
import '../auth/auth_provider.dart';

final healthProvider = StateNotifierProvider<HealthNotifier, HealthReading>((ref) {
  final notifier = HealthNotifier(ref);
  // Fetch latest stored telemetry (local storage first) on startup
  notifier.fetchLatestDataFromBackend();
  return notifier;
});

final watchConnectedProvider = StateProvider<bool>((ref) => false);
final hrSupportedProvider = StateProvider<bool>((ref) => true);    // Track whether watch hardware has HR sensor
final bpSupportedProvider = StateProvider<bool>((ref) => true);    // Track whether watch hardware has BP sensor
final stepsSupportedProvider = StateProvider<bool>((ref) => true); // Track whether watch hardware has Pedometer
final spo2SupportedProvider = StateProvider<bool>((ref) => true);  // Track whether watch hardware has SpO2 sensor


class HealthNotifier extends StateNotifier<HealthReading> {
  final Ref _ref;
  HealthNotifier(this._ref) : super(HealthReading.empty);

  final _api = ApiService();
  Timer? _syncTimer;
  final _ws = WebSocketService();
  final _pedometer = PedometerService();
  int _baseSteps = 0;

  /// Captures pre-existing app step count when watch connects so live watch steps accumulate on top of baseline
  void syncWatchBaseline() {
    _baseSteps = state.steps;
  }

  void startContinuousSync() {
    // 1. Load latest stored data first (local device storage)
    fetchLatestDataFromBackend();

    // Note: Phone mobile sensor step counting is DISABLED.
    // Step data comes 100% strictly and exclusively from the Smartwatch BLE Pedometer!

    // 2. Connect WebSocket for live push ONLY if user enabled cloud sync
    final user = _ref.read(userModelProvider);
    if (user?.settings.syncCloud == true) {
      _ws.connect(onDataReceived: (data) {
        updateFromWatch(data);
      });

      // 4. 3-second backend sync for cloud enabled accounts
      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        fetchLatestDataFromBackend();
      });
    }
  }

  void stopContinuousSync() {
    _syncTimer?.cancel();
    _ws.disconnect();
  }

  Future<void> fetchLatestDataFromBackend() async {
    // Always load local device storage reading only (Health data is 100% local)
    final localData = await StorageService.getLocalHealthReading();
    if (localData != null) {
      final localReading = HealthReading.fromJson(localData);
      state = HealthReading(
        heartRate: localReading.heartRate > 0 ? localReading.heartRate : state.heartRate,
        systolic: localReading.systolic > 0 ? localReading.systolic : state.systolic,
        diastolic: localReading.diastolic > 0 ? localReading.diastolic : state.diastolic,
        steps: localReading.steps > state.steps ? localReading.steps : state.steps,
        spo2: localReading.spo2 > 0 ? localReading.spo2 : state.spo2,
        lat: localReading.lat ?? state.lat,
        lng: localReading.lng ?? state.lng,
      );
      if (localReading.steps > _baseSteps) _baseSteps = localReading.steps;
    }
  }


  /// Smart Telemetry Merging:
  /// Updates live state AND saves reading locally to device storage.
  void updateFromWatch(Map<String, dynamic> data) {
    final Map<String, dynamic> payload = (data['payload'] is Map<String, dynamic>)
        ? data['payload']
        : data;

    final hr = payload['heartRate'] ?? payload['bpm'] ?? data['heartRate'] ?? data['bpm'];
    final sys = payload['systolic'] ?? payload['sys'] ?? data['systolic'] ?? data['sys'];
    final dia = payload['diastolic'] ?? payload['dia'] ?? data['diastolic'] ?? data['dia'];
    final st = payload['steps'] ?? data['steps'];
    final lat = payload['coordinates']?['lat'] ?? payload['lat'] ?? data['coordinates']?['lat'] ?? data['lat'];
    final lng = payload['coordinates']?['lng'] ?? payload['lng'] ?? data['coordinates']?['lng'] ?? data['lng'];

    final double validHr = (hr != null && (hr as num) > 0) ? hr.toDouble() : state.heartRate;
    final double validSys = (sys != null && (sys as num) > 0) ? sys.toDouble() : state.systolic;
    final double validDia = (dia != null && (dia as num) > 0) ? dia.toDouble() : state.diastolic;
    
    int validSteps = state.steps;
    if (st != null) {
      final int rawSteps = (st as num).toInt();
      if (rawSteps > 0) {
        if (rawSteps > validSteps) {
          validSteps = rawSteps;
        } else if (rawSteps + _baseSteps > validSteps) {
          validSteps = rawSteps + _baseSteps;
        }
      }
    }


    final sp = payload['spo2'] ?? payload['spO2'] ?? payload['oxygen'] ?? data['spo2'] ?? data['spO2'] ?? data['oxygen'];
    final int validSpo2 = (sp != null && (sp as num) > 0) ? (sp as num).toInt() : state.spo2;

    final double? validLat = (lat != null) ? (lat as num).toDouble() : state.lat;
    final double? validLng = (lng != null) ? (lng as num).toDouble() : state.lng;

    state = HealthReading(
      heartRate: validHr,
      systolic: validSys,
      diastolic: validDia,
      steps: validSteps,
      spo2: validSpo2,
      lat: validLat,
      lng: validLng,
    );

    // Save reading locally to device storage (wiped on app uninstall)
    StorageService.saveLocalHealthReading(state.toJson());
  }


  void reset() {
    stopContinuousSync();
    _baseSteps = 0;
    state = HealthReading.empty;
    StorageService.clearLocalHealthReading();
  }

  /// Only clears health data display - does NOT stop sync timers or WebSocket
  void clearData() {
    _baseSteps = 0;
    state = HealthReading.empty;
    StorageService.clearLocalHealthReading();
  }
}

