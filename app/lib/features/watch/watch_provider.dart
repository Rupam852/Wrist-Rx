import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../home/health_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

final watchProvider = StateNotifierProvider<WatchNotifier, WatchState>((ref) {
  return WatchNotifier(ref);
});

enum WatchConnectionStatus { disconnected, scanning, connecting, connected }

class WatchState {
  final WatchConnectionStatus status;
  final String? deviceName;
  final String? error;
  WatchState({this.status = WatchConnectionStatus.disconnected, this.deviceName, this.error});
  WatchState copyWith({WatchConnectionStatus? status, String? deviceName, String? error}) =>
      WatchState(status: status ?? this.status, deviceName: deviceName ?? this.deviceName, error: error ?? this.error);
}

class WatchNotifier extends StateNotifier<WatchState> {
  final Ref ref;
  WatchNotifier(this.ref) : super(WatchState());

  final _api = ApiService();
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _bleSubscription;

  Future<void> connectViaBluetooth(BluetoothDevice device) async {
    state = state.copyWith(status: WatchConnectionStatus.connecting, deviceName: device.platformName);
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await _api.post(ApiConstants.connectBluetooth, {'macAddress': device.remoteId.str});
        } catch (_) {}
      }

      // Discover BLE services & detect hardware capabilities for all 4 sensors
      bool foundHrSensor = false;
      bool foundBpSensor = false;
      bool foundSpo2Sensor = false;
      bool foundStepsSensor = false;

      try {
        final services = await device.discoverServices();
        for (final service in services) {
          final sUuid = service.uuid.toString().toLowerCase();
          if (sUuid.contains('180d') || sUuid.contains('heart')) foundHrSensor = true;
          if (sUuid.contains('1810') || sUuid.contains('bp') || sUuid.contains('pressure')) foundBpSensor = true;
          if (sUuid.contains('1822') || sUuid.contains('oximeter') || sUuid.contains('spo2')) foundSpo2Sensor = true;
          if (sUuid.contains('1814') || sUuid.contains('step') || sUuid.contains('running')) foundStepsSensor = true;

          for (final characteristic in service.characteristics) {
            final cUuid = characteristic.uuid.toString().toLowerCase();
            if (cUuid.contains('2a37')) foundHrSensor = true;
            if (cUuid.contains('2a35')) foundBpSensor = true;
            if (cUuid.contains('2a5e') || cUuid.contains('spo2') || cUuid.contains('oximeter')) foundSpo2Sensor = true;
            if (cUuid.contains('2a53') || cUuid.contains('step')) foundStepsSensor = true;

            if (characteristic.properties.notify || characteristic.properties.indicate) {
              await characteristic.setNotifyValue(true);
              _bleSubscription = characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  _parseBleBytes(value, characteristic.uuid.toString());
                }
              });
            }
          }
        }
      } catch (_) {}

      // Update hardware capability states for the connected watch
      ref.read(hrSupportedProvider.notifier).state = foundHrSensor;
      ref.read(bpSupportedProvider.notifier).state = foundBpSensor;
      ref.read(spo2SupportedProvider.notifier).state = foundSpo2Sensor;
      ref.read(stepsSupportedProvider.notifier).state = foundStepsSensor;

      state = state.copyWith(status: WatchConnectionStatus.connected);
      ref.read(watchConnectedProvider.notifier).state = true;
      ref.read(healthProvider.notifier).startContinuousSync();
    } catch (e) {
      state = state.copyWith(status: WatchConnectionStatus.disconnected, error: e.toString());
    }
  }

  Future<bool> connectViaToken(String token) async {
    state = state.copyWith(status: WatchConnectionStatus.connecting);
    try {
      await _api.post(ApiConstants.connectToken, {'token': token});
      state = state.copyWith(status: WatchConnectionStatus.connected, deviceName: 'Watch (Token)');
      ref.read(watchConnectedProvider.notifier).state = true;
      ref.read(healthProvider.notifier).startContinuousSync();
      return true;
    } catch (e) {
      state = state.copyWith(status: WatchConnectionStatus.disconnected, error: e.toString());
      return false;
    }
  }

  void _parseBleBytes(List<int> bytes, [String? uuid]) {
    if (bytes.isEmpty) return;

    // 1. Try decoding as JSON string packet
    try {
      final str = utf8.decode(bytes);
      if (str.startsWith('{') && str.endsWith('}')) {
        final Map<String, dynamic> json = jsonDecode(str);
        if (json.containsKey('heartRate') || json.containsKey('bpm')) ref.read(hrSupportedProvider.notifier).state = true;
        if (json.containsKey('systolic') || json.containsKey('bp')) ref.read(bpSupportedProvider.notifier).state = true;
        if (json.containsKey('spo2') || json.containsKey('oxygen')) ref.read(spo2SupportedProvider.notifier).state = true;
        if (json.containsKey('steps')) ref.read(stepsSupportedProvider.notifier).state = true;

        ref.read(healthProvider.notifier).updateFromWatch(json);
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          _api.post(ApiConstants.saveReading, json).catchError((_) => <String, dynamic>{});
        }
        return;
      }
    } catch (_) {}

    // 2. Standard GATT Heart Rate Characteristic (0x2A37)
    final isHeartRateUuid = uuid?.toLowerCase().contains('2a37') == true;
    if (isHeartRateUuid || bytes.length <= 4) {
      int flags = bytes[0];
      bool is16Bit = (flags & 0x01) != 0;
      int bpm = 0;
      if (is16Bit && bytes.length >= 3) {
        bpm = bytes[1] | (bytes[2] << 8);
      } else if (bytes.length >= 2) {
        bpm = bytes[1];
      }

      // Valid physiological heart rate range (40 - 240 BPM)
      if (bpm >= 40 && bpm <= 240) {
        ref.read(hrSupportedProvider.notifier).state = true;
        final data = {'heartRate': bpm};
        ref.read(healthProvider.notifier).updateFromWatch(data);
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          _api.post(ApiConstants.saveReading, data).catchError((_) => <String, dynamic>{});
        }
        return;
      }
    }

    // 3. Standard GATT Blood Pressure Measurement (0x2A35)
    final isBpUuid = uuid?.toLowerCase().contains('2a35') == true;
    if (isBpUuid && bytes.length >= 5) {
      int sys = bytes[1] | (bytes[2] << 8);
      int dia = bytes[3] | (bytes[4] << 8);
      if (sys >= 60 && sys <= 240 && dia >= 30 && dia <= 160) {
        ref.read(bpSupportedProvider.notifier).state = true;
        final data = {'systolic': sys, 'diastolic': dia};
        ref.read(healthProvider.notifier).updateFromWatch(data);
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          _api.post(ApiConstants.saveReading, data).catchError((_) => <String, dynamic>{});
        }
        return;
      }
    }

    // 4. Standard GATT Pulse Oximeter / SpO2 Characteristic (0x2A5E / SpO2)
    final isSpo2Uuid = uuid?.toLowerCase().contains('2a5e') == true || uuid?.toLowerCase().contains('spo2') == true;
    if (isSpo2Uuid && bytes.length >= 2) {
      int ox = bytes[1];
      if (ox >= 70 && ox <= 100) {
        ref.read(spo2SupportedProvider.notifier).state = true;
        final data = {'spo2': ox};
        ref.read(healthProvider.notifier).updateFromWatch(data);
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          _api.post(ApiConstants.saveReading, data).catchError((_) => <String, dynamic>{});
        }
        return;
      }
    }
  }

  Future<void> disconnect() async {
    _bleSubscription?.cancel();
    await _connectedDevice?.disconnect();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try { await _api.post(ApiConstants.disconnectWatch(uid), {}); } catch (_) {}
    }
    _connectedDevice = null;
    ref.read(healthProvider.notifier).reset();
    ref.read(watchConnectedProvider.notifier).state = false;
    ref.read(hrSupportedProvider.notifier).state = true;
    ref.read(bpSupportedProvider.notifier).state = true;
    ref.read(spo2SupportedProvider.notifier).state = true;
    ref.read(stepsSupportedProvider.notifier).state = true;
    state = WatchState();
  }
}
