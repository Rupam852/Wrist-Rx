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

      // Open all hardware metric capabilities by default
      ref.read(hrSupportedProvider.notifier).state = true;
      ref.read(bpSupportedProvider.notifier).state = true;
      ref.read(spo2SupportedProvider.notifier).state = true;
      ref.read(stepsSupportedProvider.notifier).state = true;

      // Discover BLE services & subscribe to all notify/indicate characteristics
      try {
        final services = await device.discoverServices();
        for (final service in services) {
          for (final characteristic in service.characteristics) {
            // Read initial value if readable
            if (characteristic.properties.read) {
              try {
                final initialBytes = await characteristic.read();
                if (initialBytes.isNotEmpty) {
                  _parseBleBytes(initialBytes, characteristic.uuid.toString());
                }
              } catch (_) {}
            }

            // Enable Notifications / Indications
            if (characteristic.properties.notify || characteristic.properties.indicate) {
              await characteristic.setNotifyValue(true);
              _bleSubscription = characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  _parseBleBytes(value, characteristic.uuid.toString());
                }
              });
            }

            // Send trigger sync ping if writable (Triggers telemetry stream on Chinese & Custom Watch Chipsets)
            if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
              try {
                // Common sync trigger bytes [0xAB, 0x00, 0x04, 0xFF, 0x31] or [0x55, 0x01]
                await characteristic.write([0xAB, 0x00, 0x04, 0xFF, 0x31], withoutResponse: characteristic.properties.writeWithoutResponse);
              } catch (_) {}
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

    final u = uuid?.toLowerCase() ?? '';

    // 2. Standard GATT Heart Rate Characteristic (0x2A37)
    if (u.contains('2a37')) {
      int flags = bytes[0];
      bool is16Bit = (flags & 0x01) != 0;
      int bpm = 0;
      if (is16Bit && bytes.length >= 3) {
        bpm = bytes[1] | (bytes[2] << 8);
      } else if (bytes.length >= 2) {
        bpm = bytes[1];
      }

      if (bpm >= 40 && bpm <= 240) {
        ref.read(hrSupportedProvider.notifier).state = true;
        _saveAndPush({'heartRate': bpm});
        return;
      }
    }

    // 3. Standard GATT Blood Pressure Measurement (0x2A35)
    if (u.contains('2a35') && bytes.length >= 5) {
      int sys = bytes[1] | (bytes[2] << 8);
      int dia = bytes[3] | (bytes[4] << 8);
      if (sys >= 60 && sys <= 240 && dia >= 30 && dia <= 160) {
        ref.read(bpSupportedProvider.notifier).state = true;
        _saveAndPush({'systolic': sys, 'diastolic': dia});
        return;
      }
    }

    // 4. Standard GATT Pulse Oximeter / SpO2 Characteristic (0x2A5E / SpO2)
    if ((u.contains('2a5e') || u.contains('spo2')) && bytes.length >= 2) {
      int ox = bytes[1];
      if (ox >= 70 && ox <= 100) {
        ref.read(spo2SupportedProvider.notifier).state = true;
        _saveAndPush({'spo2': ox});
        return;
      }
    }

    // 5. Standard GATT RSC / Pedometer Step Count (0x2A53)
    if (u.contains('2a53') && bytes.length >= 3) {
      int steps = bytes[1] | (bytes[2] << 8);
      if (bytes.length >= 5) {
        steps = bytes[1] | (bytes[2] << 8) | (bytes[3] << 16) | (bytes[4] << 24);
      }
      if (steps > 0 && steps < 200000) {
        ref.read(stepsSupportedProvider.notifier).state = true;
        _saveAndPush({'steps': steps});
        return;
      }
    }

    // 6. Header-Prefixed Smartwatch Vendor Packets (0xAB, 0x55, 0xAA, 0xFA, 0xFC, 0x7C)
    final firstByte = bytes[0];
    if (firstByte == 0xAB || firstByte == 0x55 || firstByte == 0xAA || firstByte == 0xFA || firstByte == 0xFC || firstByte == 0x7C) {
      // Packet format: [Header, Cmd/Len, BPM, SYS, DIA, SpO2, Steps_Hi, Steps_Lo, ...]
      int offset = (bytes.length >= 4 && (bytes[1] < 10)) ? 2 : 1;
      int bpm = (bytes.length > offset) ? bytes[offset] : 0;
      int sys = (bytes.length > offset + 1) ? bytes[offset + 1] : 0;
      int dia = (bytes.length > offset + 2) ? bytes[offset + 2] : 0;
      int ox = (bytes.length > offset + 3) ? bytes[offset + 3] : 0;
      int steps = (bytes.length >= offset + 6) ? ((bytes[offset + 4] << 8) | bytes[offset + 5]) : 0;

      final Map<String, dynamic> data = {};
      if (bpm >= 40 && bpm <= 240) { data['heartRate'] = bpm; ref.read(hrSupportedProvider.notifier).state = true; }
      if (sys >= 60 && sys <= 240 && dia >= 30 && dia <= 160) {
        data['systolic'] = sys; data['diastolic'] = dia;
        ref.read(bpSupportedProvider.notifier).state = true;
      }
      if (ox >= 70 && ox <= 100) { data['spo2'] = ox; ref.read(spo2SupportedProvider.notifier).state = true; }
      if (steps > 0 && steps < 200000) { data['steps'] = steps; ref.read(stepsSupportedProvider.notifier).state = true; }

      if (data.isNotEmpty) {
        _saveAndPush(data);
        return;
      }
    }

    // 7. Plain Byte Array telemetry [BPM, SYS, DIA, SpO2, Steps_Hi, Steps_Lo]
    if (bytes.length >= 2) {
      int bpm = bytes[0];
      int sys = (bytes.length >= 3) ? bytes[1] : 0;
      int dia = (bytes.length >= 3) ? bytes[2] : 0;
      int ox = (bytes.length >= 4) ? bytes[3] : 0;
      int steps = (bytes.length >= 6) ? ((bytes[4] << 8) | bytes[5]) : 0;

      final Map<String, dynamic> data = {};
      if (bpm >= 40 && bpm <= 240) { data['heartRate'] = bpm; ref.read(hrSupportedProvider.notifier).state = true; }
      if (sys >= 60 && sys <= 240 && dia >= 30 && dia <= 160) {
        data['systolic'] = sys; data['diastolic'] = dia;
        ref.read(bpSupportedProvider.notifier).state = true;
      }
      if (ox >= 70 && ox <= 100) { data['spo2'] = ox; ref.read(spo2SupportedProvider.notifier).state = true; }
      if (steps > 0 && steps < 200000) { data['steps'] = steps; ref.read(stepsSupportedProvider.notifier).state = true; }

      if (data.isNotEmpty) {
        _saveAndPush(data);
      }
    }
  }

  void _saveAndPush(Map<String, dynamic> data) {
    ref.read(healthProvider.notifier).updateFromWatch(data);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _api.post(ApiConstants.saveReading, data).catchError((_) => <String, dynamic>{});
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
