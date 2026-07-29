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

      // Discover BLE services & subscribe to notify/indicate characteristics
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

            // Enable Notifications / Indications
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

      // Send multi-probe sync commands immediately to pull latest steps, HR, and SpO2 from watch memory
      _triggerWatchSync();

      // Start 4-second continuous sync ping loop to pull latest telemetry
      _watchPingTimer?.cancel();
      _watchPingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
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
      // Command 1: General Telemetry Sync
      await _writeCharacteristic!.write([0xAB, 0x00, 0x04, 0xFF, 0x31], withoutResponse: noResp);
      // Command 2: Pedometer / Steps Sync
      await _writeCharacteristic!.write([0xAB, 0x00, 0x04, 0xFF, 0x51], withoutResponse: noResp);
      // Command 3: HR & SpO2 Sync
      await _writeCharacteristic!.write([0xAB, 0x00, 0x04, 0xFF, 0x52], withoutResponse: noResp);
      // Command 4: Vendor Pedometer Sync
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

    // 4. Standard GATT Pulse Oximeter / SpO2 Characteristic (0x2A5E / 0x1822) — ONLY updates SpO2
    if ((u.contains('2a5e') || u.contains('1822') || u.contains('spo2') || u.contains('oximeter')) && bytes.length >= 2) {
      int ox = bytes[1];
      if (ox >= 70 && ox <= 100) {
        ref.read(spo2SupportedProvider.notifier).state = true;
        _saveAndPush({'spo2': ox});
        return;
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

    // 6. Header-Prefixed Smartwatch Vendor Packets (0xAB, 0x55, 0xAA, 0xFA, 0xFC, 0x7C)
    final firstByte = bytes[0];
    if (firstByte == 0xAB || firstByte == 0x55 || firstByte == 0xAA || firstByte == 0xFA || firstByte == 0xFC || firstByte == 0x7C) {
      int cmdByte = (bytes.length >= 2) ? bytes[1] : 0;

      // Heart Rate Measurement Command (0x0A, 0x09, 0x51) -> ONLY update heart rate!
      if ((cmdByte == 0x0A || cmdByte == 0x09 || cmdByte == 0x51) && bytes.length >= 3) {
        int bpm = bytes[2];
        if (bpm >= 40 && bpm <= 240) {
          ref.read(hrSupportedProvider.notifier).state = true;
          _saveAndPush({'heartRate': bpm});
          return;
        }
      }

      // SpO2 Blood Oxygen Command (0x12, 0x0C, 0x27, 0x53) -> ONLY update SpO2!
      if ((cmdByte == 0x12 || cmdByte == 0x0C || cmdByte == 0x27 || cmdByte == 0x53) && bytes.length >= 3) {
        int ox = bytes[2];
        if (ox >= 70 && ox <= 100) {
          ref.read(spo2SupportedProvider.notifier).state = true;
          _saveAndPush({'spo2': ox});
          return;
        }
      }

      // Blood Pressure Command (0x52) -> ONLY update Systolic & Diastolic!
      if (cmdByte == 0x52 && bytes.length >= 4) {
        int sys = bytes[2];
        int dia = bytes[3];
        if (sys >= 60 && sys <= 240 && dia >= 30 && dia <= 160) {
          ref.read(bpSupportedProvider.notifier).state = true;
          _saveAndPush({'systolic': sys, 'diastolic': dia});
          return;
        }
      }

      // Pedometer Steps Command (0x02, 0x07, 0x51) -> ONLY update Steps!
      if ((cmdByte == 0x02 || cmdByte == 0x07 || cmdByte == 0x51) && bytes.length >= 4) {
        int steps = (bytes[2] << 8) | bytes[3];
        if (bytes.length >= 6) steps = (bytes[2] << 24) | (bytes[3] << 16) | (bytes[4] << 8) | bytes[5];
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
    _bleSubscription?.cancel();
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
