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

      // Default all health metric capabilities to true when connected
      ref.read(hrSupportedProvider.notifier).state = true;
      ref.read(bpSupportedProvider.notifier).state = true;
      ref.read(spo2SupportedProvider.notifier).state = true;
      ref.read(stepsSupportedProvider.notifier).state = true;

      // Discover BLE services & subscribe to all notify/indicate characteristics
      try {
        final services = await device.discoverServices();
        for (final service in services) {
          for (final characteristic in service.characteristics) {
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
    if (isHeartRateUuid) {
      int flags = bytes[0];
      bool is16Bit = (flags & 0x01) != 0;
      int bpm = 0;
      if (is16Bit && bytes.length >= 3) {
        bpm = bytes[1] | (bytes[2] << 8);
      } else if (bytes.length >= 2) {
        bpm = bytes[1];
      }

      if (bpm >= 40 && bpm <= 240) {
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
        final data = {'spo2': ox};
        ref.read(healthProvider.notifier).updateFromWatch(data);
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          _api.post(ApiConstants.saveReading, data).catchError((_) => <String, dynamic>{});
        }
        return;
      }
    }

    // 5. Universal Multi-Metric Packet Parser (Supports custom smartwatch vendor protocols)
    if (bytes.length >= 2) {
      int possibleBpm = bytes[0];
      int possibleSys = (bytes.length >= 3) ? bytes[1] : 0;
      int possibleDia = (bytes.length >= 3) ? bytes[2] : 0;
      int possibleSpo2 = (bytes.length >= 4) ? bytes[3] : 0;
      int possibleSteps = (bytes.length >= 6) ? ((bytes[4] << 8) | bytes[5]) : 0;

      final Map<String, dynamic> data = {};
      if (possibleBpm >= 40 && possibleBpm <= 240) data['heartRate'] = possibleBpm;
      if (possibleSys >= 60 && possibleSys <= 240 && possibleDia >= 30 && possibleDia <= 160) {
        data['systolic'] = possibleSys;
        data['diastolic'] = possibleDia;
      }
      if (possibleSpo2 >= 70 && possibleSpo2 <= 100) data['spo2'] = possibleSpo2;
      if (possibleSteps > 0 && possibleSteps < 200000) data['steps'] = possibleSteps;

      if (data.isNotEmpty) {
        ref.read(healthProvider.notifier).updateFromWatch(data);
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          _api.post(ApiConstants.saveReading, data).catchError((_) => <String, dynamic>{});
        }
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
