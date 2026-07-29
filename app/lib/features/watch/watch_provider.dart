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
  final List<StreamSubscription> _bleSubscriptions = [];
  Timer? _watchPingTimer;
  BluetoothCharacteristic? _writeCharacteristic;

  Future<void> connectViaBluetooth(BluetoothDevice device) async {
    state = state.copyWith(status: WatchConnectionStatus.connecting, deviceName: device.platformName);
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await _api.post(ApiConstants.connectBluetooth, {'macAddress': device.remoteId.str});
          // Auto wipe old stored telemetry for clean fresh watch session
          await _api.delete(ApiConstants.cleanHealthData(uid));
        } catch (_) {}
      }

      // Reset state for clean fresh start with newly connected watch
      ref.read(healthProvider.notifier).reset();

      // Open all hardware metric capabilities by default
      ref.read(hrSupportedProvider.notifier).state = true;
      ref.read(bpSupportedProvider.notifier).state = true;
      ref.read(spo2SupportedProvider.notifier).state = true;
      ref.read(stepsSupportedProvider.notifier).state = true;

      // Discover BLE services & subscribe to ALL notify/indicate characteristics
      try {
        final services = await device.discoverServices();
        for (final service in services) {
          for (final characteristic in service.characteristics) {
            // Save write characteristic for active sync pings
            if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
              _writeCharacteristic = characteristic;
            }

            // Read initial stored values immediately if characteristic is readable
            if (characteristic.properties.read) {
              try {
                final initialBytes = await characteristic.read();
                if (initialBytes.isNotEmpty) {
                  _parseBleBytes(initialBytes, characteristic.uuid.toString());
                }
              } catch (_) {}
            }

            // Enable Notifications / Indications for ALL characteristics in parallel
            if (characteristic.properties.notify || characteristic.properties.indicate) {
              try {
                await characteristic.setNotifyValue(true);
                final sub = characteristic.lastValueStream.listen((value) {
                  if (value.isNotEmpty) {
                    _parseBleBytes(value, characteristic.uuid.toString());
                  }
                });
                _bleSubscriptions.add(sub);
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      // Send multi-probe sync commands immediately to pull latest steps, HR, and SpO2 from watch memory
      _triggerWatchSync();

      // Start 3-second continuous sync ping loop for real-time SpO2, HR, and Step streaming
      _watchPingTimer?.cancel();
      _watchPingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _triggerWatchSync();
      });

      state = state.copyWith(status: WatchConnectionStatus.connected);
      ref.read(watchConnectedProvider.notifier).state = true;
      ref.read(healthProvider.notifier).startContinuousSync();
    } catch (e) {
      state = state.copyWith(status: WatchConnectionStatus.disconnected, error: e.toString());
    }
  }

  void _triggerWatchSync() async {
    if (_writeCharacteristic == null) return;
    try {
      final noResp = _writeCharacteristic!.properties.writeWithoutResponse;
      // General Telemetry Sync
      await _writeCharacteristic!.write([0xAB, 0x00, 0x04, 0xFF, 0x31], withoutResponse: noResp);
      // SpO2 Blood Oxygen Active Measurement Probes (5-byte & 3-byte protocol variants)
      await _writeCharacteristic!.write([0xAB, 0x00, 0x04, 0xFF, 0x12], withoutResponse: noResp);
      await _writeCharacteristic!.write([0xAB, 0x00, 0x04, 0xFF, 0x11], withoutResponse: noResp);
      await _writeCharacteristic!.write([0xAB, 0x00, 0x04, 0xFF, 0x53], withoutResponse: noResp);
      await _writeCharacteristic!.write([0xAB, 0x12], withoutResponse: noResp);
      await _writeCharacteristic!.write([0xAB, 0x11], withoutResponse: noResp);
      await _writeCharacteristic!.write([0x55, 0x12], withoutResponse: noResp);
      await _writeCharacteristic!.write([0x55, 0x11], withoutResponse: noResp);
      // Heart Rate Probes
      await _writeCharacteristic!.write([0xAB, 0x00, 0x04, 0xFF, 0x52], withoutResponse: noResp);
      await _writeCharacteristic!.write([0xAB, 0x0A], withoutResponse: noResp);
      await _writeCharacteristic!.write([0x55, 0x0A], withoutResponse: noResp);
      // Pedometer / Steps Probes
      await _writeCharacteristic!.write([0xAB, 0x00, 0x04, 0xFF, 0x51], withoutResponse: noResp);
      await _writeCharacteristic!.write([0x55, 0x01], withoutResponse: noResp);
      await _writeCharacteristic!.write([0x55, 0x02], withoutResponse: noResp);
    } catch (_) {}
  }

  Future<bool> connectViaToken(String token) async {
    state = state.copyWith(status: WatchConnectionStatus.connecting);
    try {
      await _api.post(ApiConstants.connectToken, {'token': token});

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try { await _api.delete(ApiConstants.cleanHealthData(uid)); } catch (_) {}
      }
      ref.read(healthProvider.notifier).reset();

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

    // 1. JSON String Packet Parser
    try {
      final str = utf8.decode(bytes);
      if (str.startsWith('{') && str.endsWith('}')) {
        final Map<String, dynamic> json = jsonDecode(str);
        _saveAndPush(json);
        return;
      }
    } catch (_) {}

    final u = uuid?.toLowerCase() ?? '';

    // 2. Standard GATT Heart Rate Characteristic (0x2A37 / 0x180D) — ONLY updates Heart Rate
    if (u.contains('2a37') || u.contains('180d')) {
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

    // 3. Standard GATT Blood Pressure Measurement (0x2A35 / 0x1810) — ONLY updates Blood Pressure
    if ((u.contains('2a35') || u.contains('1810')) && bytes.length >= 5) {
      int sys = bytes[1] | (bytes[2] << 8);
      int dia = bytes[3] | (bytes[4] << 8);
      if (sys >= 60 && sys <= 240 && dia >= 30 && dia <= 160) {
        ref.read(bpSupportedProvider.notifier).state = true;
        _saveAndPush({'systolic': sys, 'diastolic': dia});
        return;
      }
    }

    // 4. Standard GATT Pulse Oximeter / SpO2 Characteristic (0x2A5E / 0x2A5F / 0x2A60 / 0x1822 / spo2 / oximeter / oxygen)
    if (u.contains('2a5e') || u.contains('2a5f') || u.contains('2a60') || u.contains('1822') || u.contains('spo2') || u.contains('oximeter') || u.contains('oxygen')) {
      for (int i = 0; i < bytes.length; i++) {
        int ox = bytes[i];
        if (ox >= 70 && ox <= 100) {
          ref.read(spo2SupportedProvider.notifier).state = true;
          _saveAndPush({'spo2': ox});
          return;
        }
      }
    }

    // 5. Standard GATT RSC / Pedometer Step Count (0x2A53 / 0x1814) — ONLY updates Steps
    if ((u.contains('2a53') || u.contains('1814') || u.contains('pedometer') || u.contains('step')) && bytes.length >= 3) {
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

    // 6. Universal Smartwatch Vendor Protocol Parser (Supports 3-byte, 5-byte, & variable header packets)
    final firstByte = bytes[0];
    if (firstByte == 0xAB || firstByte == 0x55 || firstByte == 0xAA || firstByte == 0xFA || firstByte == 0xFC || firstByte == 0x7C || firstByte == 0x00) {

      // A) Check for SpO2 Command Code at ANY position in header bytes [1..min(4, length-1)]
      bool isSpO2Cmd = false;
      for (int i = 1; i < bytes.length && i <= 4; i++) {
        int c = bytes[i];
        if (c == 0x12 || c == 0x11 || c == 0x0C || c == 0x27 || c == 0x53 || c == 0x1B || c == 0x18 || c == 0x28) {
          isSpO2Cmd = true;
          break;
        }
      }

      if (isSpO2Cmd && bytes.length >= 3) {
        // Scan for SpO2 percentage (70% to 100%) across payload
        for (int i = 2; i < bytes.length; i++) {
          int ox = bytes[i];
          if (ox >= 70 && ox <= 100) {
            ref.read(spo2SupportedProvider.notifier).state = true;
            _saveAndPush({'spo2': ox});
            return;
          }
        }
      }

      // B) Check for Heart Rate Command Code at ANY position in header bytes [1..min(4, length-1)]
      bool isHRCmd = false;
      for (int i = 1; i < bytes.length && i <= 4; i++) {
        int c = bytes[i];
        if (c == 0x0A || c == 0x09 || c == 0x51 || c == 0x14 || c == 0x08) {
          isHRCmd = true;
          break;
        }
      }

      if (isHRCmd && bytes.length >= 3) {
        for (int i = 2; i < bytes.length; i++) {
          int bpm = bytes[i];
          if (bpm >= 40 && bpm <= 240) {
            ref.read(hrSupportedProvider.notifier).state = true;
            _saveAndPush({'heartRate': bpm});
            return;
          }
        }
      }

      // C) Check for Blood Pressure Command Code
      bool isBPCmd = false;
      for (int i = 1; i < bytes.length && i <= 4; i++) {
        if (bytes[i] == 0x52) { isBPCmd = true; break; }
      }

      if (isBPCmd && bytes.length >= 4) {
        int sys = bytes[bytes.length >= 5 ? 3 : 2];
        int dia = bytes[bytes.length >= 5 ? 4 : 3];
        if (sys >= 60 && sys <= 240 && dia >= 30 && dia <= 160) {
          ref.read(bpSupportedProvider.notifier).state = true;
          _saveAndPush({'systolic': sys, 'diastolic': dia});
          return;
        }
      }

      // D) Check for Pedometer Steps Command Code
      bool isStepCmd = false;
      for (int i = 1; i < bytes.length && i <= 4; i++) {
        int c = bytes[i];
        if (c == 0x02 || c == 0x07 || c == 0x31) {
          isStepCmd = true;
          break;
        }
      }

      if (isStepCmd && bytes.length >= 4) {
        int startIdx = bytes.length >= 6 ? 3 : 2;
        int steps = (bytes[startIdx] << 8) | bytes[startIdx + 1];
        if (bytes.length >= startIdx + 4) {
          steps = (bytes[startIdx] << 24) | (bytes[startIdx + 1] << 16) | (bytes[startIdx + 2] << 8) | bytes[startIdx + 3];
        }
        if (steps > 0 && steps < 200000) {
          ref.read(stepsSupportedProvider.notifier).state = true;
          _saveAndPush({'steps': steps});
          return;
        }
      }
    }
  }

  /// Merges single metric update into full HealthReading and saves complete reading to backend database
  void _saveAndPush(Map<String, dynamic> data) {
    ref.read(healthProvider.notifier).updateFromWatch(data);
    final fullState = ref.read(healthProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _api.post(ApiConstants.saveReading, fullState.toJson()).catchError((_) => <String, dynamic>{});
    }
  }

  Future<void> disconnect() async {
    _watchPingTimer?.cancel();
    for (final sub in _bleSubscriptions) {
      try { await sub.cancel(); } catch (_) {}
    }
    _bleSubscriptions.clear();

    await _connectedDevice?.disconnect();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try { await _api.post(ApiConstants.disconnectWatch(uid), {}); } catch (_) {}
    }
    _connectedDevice = null;
    _writeCharacteristic = null;
    ref.read(healthProvider.notifier).reset();
    ref.read(watchConnectedProvider.notifier).state = false;
    ref.read(hrSupportedProvider.notifier).state = true;
    ref.read(bpSupportedProvider.notifier).state = true;
    ref.read(spo2SupportedProvider.notifier).state = true;
    ref.read(stepsSupportedProvider.notifier).state = true;
    state = WatchState();
  }
}
