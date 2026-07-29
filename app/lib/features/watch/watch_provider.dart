import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/foreground_service.dart';
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
  final List<BluetoothCharacteristic> _writeCharacteristics = [];
  final List<BluetoothCharacteristic> _readableCharacteristics = [];
  Timer? _watchPingTimer;
  int _pingCycle = 0; // Rotating probe cycle index

  Future<void> connectViaBluetooth(BluetoothDevice device) async {
    state = state.copyWith(status: WatchConnectionStatus.connecting, deviceName: device.platformName);
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;
      _writeCharacteristics.clear();
      _readableCharacteristics.clear();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await _api.post(ApiConstants.connectBluetooth, {'macAddress': device.remoteId.str});
        } catch (_) {}
      }

      // Sync pre-existing app step baseline before receiving live watch telemetry
      ref.read(healthProvider.notifier).syncWatchBaseline();

      // Open all hardware metric capabilities by default
      ref.read(hrSupportedProvider.notifier).state = true;
      ref.read(bpSupportedProvider.notifier).state = true;
      ref.read(stepsSupportedProvider.notifier).state = true;


      // Discover BLE services & subscribe to ALL notify/indicate characteristics continuously
      try {
        final services = await device.discoverServices();
        for (final service in services) {
          for (final characteristic in service.characteristics) {
            // Collect ALL writable characteristics for parallel command probes
            if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
              _writeCharacteristics.add(characteristic);
            }

            // Collect readable characteristics for periodic polling & read initial values immediately
            if (characteristic.properties.read) {
              _readableCharacteristics.add(characteristic);
              try {
                final initialBytes = await characteristic.read();
                if (initialBytes.isNotEmpty) {
                  _parseBleBytes(initialBytes, characteristic.uuid.toString());
                }
              } catch (_) {}
            }

            // Enable Notifications / Indications - attach lastValueStream BEFORE setNotifyValue so initial notification is captured
            if (characteristic.properties.notify || characteristic.properties.indicate) {
              try {
                final sub = characteristic.lastValueStream.listen(
                  (value) {
                    if (value.isNotEmpty) {
                      _parseBleBytes(value, characteristic.uuid.toString());
                    }
                  },
                  onError: (_) {},
                  cancelOnError: false,
                );
                _bleSubscriptions.add(sub);
                await characteristic.setNotifyValue(true);
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      // Send initial sync commands immediately in burst to pull latest steps, HR, and SpO2 from watch memory
      _triggerWatchSync();
      Future.delayed(const Duration(milliseconds: 500), () => _triggerWatchSync());
      Future.delayed(const Duration(milliseconds: 1500), () => _triggerWatchSync());

      // Start non-stopping 3-second rotating probe sync - avoids flooding the watch
      _watchPingTimer?.cancel();
      _pingCycle = 0;
      _watchPingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _triggerWatchSync();
      });

      state = state.copyWith(status: WatchConnectionStatus.connected);
      ref.read(watchConnectedProvider.notifier).state = true;
      ref.read(healthProvider.notifier).startContinuousSync();

      // Start foreground service to keep BLE connection alive in background/when app closed
      WatchForegroundService().start(watchName: device.platformName).catchError((_) => null);
    } catch (e) {
      state = state.copyWith(status: WatchConnectionStatus.disconnected, error: e.toString());
    }
  }

  /// Sends smart sync probes every cycle:
  /// - Steps: ALWAYS (live pedometer must update every tick)
  /// - HR and SpO2: alternate each cycle to avoid flooding
  void _triggerWatchSync() async {
    // 1. Poll readable characteristics continuously for watches that don't auto-notify
    for (final char in _readableCharacteristics) {
      try {
        final val = await char.read();
        if (val.isNotEmpty) {
          _parseBleBytes(val, char.uuid.toString());
        }
      } catch (_) {}
    }

    if (_writeCharacteristics.isEmpty) return;

    final cycle = _pingCycle % 2; // Only 2 alternating cycles now
    _pingCycle++;

    for (final char in _writeCharacteristics) {
      try {
        final noResp = char.properties.writeWithoutResponse;

        // ── ALWAYS: General sync + Steps (pull current & stored step count) ──
        char.write([0xAB, 0x00, 0x04, 0xFF, 0x31], withoutResponse: noResp).catchError((_) => null);
        char.write([0xAB, 0x00, 0x04, 0xFF, 0x51], withoutResponse: noResp).catchError((_) => null);
        char.write([0xAB, 0x51], withoutResponse: noResp).catchError((_) => null);
        char.write([0xAB, 0x31], withoutResponse: noResp).catchError((_) => null);
        char.write([0xAB, 0x07], withoutResponse: noResp).catchError((_) => null);
        char.write([0x55, 0x01], withoutResponse: noResp).catchError((_) => null);
        char.write([0x55, 0x02], withoutResponse: noResp).catchError((_) => null);
        char.write([0x55, 0x51], withoutResponse: noResp).catchError((_) => null);
        char.write([0xAA, 0x01], withoutResponse: noResp).catchError((_) => null);
        char.write([0xEA, 0x01], withoutResponse: noResp).catchError((_) => null);

        if (cycle == 0) {
          // Heart Rate probe cycle
          char.write([0xAB, 0x00, 0x04, 0xFF, 0x52], withoutResponse: noResp).catchError((_) => null);
          char.write([0xAB, 0x0A], withoutResponse: noResp).catchError((_) => null);
          char.write([0x55, 0x0A], withoutResponse: noResp).catchError((_) => null);
        } else {
          // SpO2 Blood Oxygen probe cycle - covers all known SpO2 command codes
          char.write([0xAB, 0x00, 0x04, 0xFF, 0x12], withoutResponse: noResp).catchError((_) => null);
          char.write([0xAB, 0x00, 0x04, 0xFF, 0x11], withoutResponse: noResp).catchError((_) => null);
          char.write([0xAB, 0x00, 0x04, 0xFF, 0x53], withoutResponse: noResp).catchError((_) => null);
          char.write([0xAB, 0x12], withoutResponse: noResp).catchError((_) => null);
          char.write([0xAB, 0x11], withoutResponse: noResp).catchError((_) => null);
          char.write([0x55, 0x12], withoutResponse: noResp).catchError((_) => null);
          char.write([0x55, 0x11], withoutResponse: noResp).catchError((_) => null);
          // Additional SpO2 codes used by many Chinese OEM watches
          char.write([0xAB, 0x18], withoutResponse: noResp).catchError((_) => null);
          char.write([0xAB, 0x1B], withoutResponse: noResp).catchError((_) => null);
          char.write([0x55, 0x18], withoutResponse: noResp).catchError((_) => null);
        }
      } catch (_) {}
    }
  }

  Future<bool> connectViaToken(String token) async {
    state = state.copyWith(status: WatchConnectionStatus.connecting);
    try {
      await _api.post(ApiConstants.connectToken, {'token': token});

      ref.read(healthProvider.notifier).syncWatchBaseline();

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

    // 1. JSON String Packet Parser (highest priority)
    try {
      final str = utf8.decode(bytes);
      if (str.startsWith('{') && str.endsWith('}')) {
        final Map<String, dynamic> json = jsonDecode(str);
        _saveAndPush(json);
        return;
      }
    } catch (_) {}

    final u = uuid?.toLowerCase() ?? '';

    // ── PRIORITY 1: Standard GATT Characteristics by UUID ──────────────────

    // Standard GATT Heart Rate Measurement (0x2A37 / service 0x180D)
    if (u.contains('2a37') || u.contains('180d')) {
      if (bytes.length >= 2) {
        int flags = bytes[0];
        bool is16Bit = (flags & 0x01) != 0;
        int bpm = 0;
        if (is16Bit && bytes.length >= 3) {
          bpm = bytes[1] | (bytes[2] << 8);
        } else {
          bpm = bytes[1];
        }
        if (bpm >= 40 && bpm <= 240) {
          ref.read(hrSupportedProvider.notifier).state = true;
          _saveAndPush({'heartRate': bpm});
          return;
        }
      }
      return; // This UUID is HR - don't fall through to SpO2 parser
    }

    // Standard GATT Blood Pressure Measurement (0x2A35 / service 0x1810)
    if (u.contains('2a35') || u.contains('1810')) {
      if (bytes.length >= 5) {
        int sys = bytes[1] | (bytes[2] << 8);
        int dia = bytes[3] | (bytes[4] << 8);
        if (sys >= 60 && sys <= 240 && dia >= 30 && dia <= 160) {
          ref.read(bpSupportedProvider.notifier).state = true;
          _saveAndPush({'systolic': sys, 'diastolic': dia});
          return;
        }
      }
      return; // This UUID is BP - don't fall through
    }

    // Standard GATT RSC / Step Counter (0x2A53 / service 0x1814, 0x2A56 pedometer)
    if (u.contains('2a53') || u.contains('1814') || u.contains('2a56') ||
        u.contains('pedometer') || u.contains('step')) {
      if (bytes.length >= 3) {
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
      return; // This UUID is Steps - don't fall through
    }

    // ── PRIORITY 2: Vendor/Proprietary Protocol by Header Byte ─────────────

    if (bytes.length < 2) return;
    final firstByte = bytes[0];

    // Only process known vendor protocol headers
    if (firstByte != 0xAB && firstByte != 0x55 && firstByte != 0xAA &&
        firstByte != 0xFA && firstByte != 0xFC && firstByte != 0x7C &&
        firstByte != 0xEA && firstByte != 0x04 && firstByte != 0x68 &&
        firstByte != 0xCD && firstByte != 0x80) {
      return;
    }

    final cmdByte = bytes[1];
    // Check for longer header format: AB 00 04 FF XX
    final cmd4 = (bytes.length >= 5 && bytes[1] == 0x00 && bytes[2] == 0x04 && bytes[3] == 0xFF) ? bytes[4] : 0x00;
    final effectiveCmd = cmd4 != 0x00 ? cmd4 : cmdByte;
    final dataStart = cmd4 != 0x00 ? 5 : 2;

    // ── Vendor Heart Rate Response ──────────────────────────────────────────
    // Command codes: 0x0A (HR measurement), 0x09
    // NOTE: 0x51 is NOT here — 0x51 is a STEPS response code (we use it as steps probe)
    if (effectiveCmd == 0x0A || effectiveCmd == 0x09) {
      for (int i = dataStart; i < bytes.length; i++) {
        int bpm = bytes[i];
        if (bpm >= 40 && bpm <= 240) {
          ref.read(hrSupportedProvider.notifier).state = true;
          _saveAndPush({'heartRate': bpm});
          return;
        }
      }
      return; // HR packet - done
    }

    // ── Vendor Blood Pressure Response ─────────────────────────────────────
    // Command code: 0x52
    if (effectiveCmd == 0x52) {
      if (bytes.length >= dataStart + 2) {
        int sys = bytes[dataStart];
        int dia = bytes[dataStart + 1];
        if (sys >= 60 && sys <= 240 && dia >= 30 && dia <= 160) {
          ref.read(bpSupportedProvider.notifier).state = true;
          _saveAndPush({'systolic': sys, 'diastolic': dia});
          return;
        }
      }
      return;
    }

    // ── Vendor Pedometer/Steps Response ────────────────────────────────────
    // Command codes: 0x02, 0x07, 0x31, 0x51, 0x01, 0x08, 0x0B, 0x1E
    final bool isStepCmd = (effectiveCmd == 0x02 || effectiveCmd == 0x07 ||
                      effectiveCmd == 0x31 || effectiveCmd == 0x51 ||
                      effectiveCmd == 0x01 || effectiveCmd == 0x08 ||
                      effectiveCmd == 0x0B || effectiveCmd == 0x1E);

    int extractedSteps = 0;
    for (int offset = dataStart; offset + 2 <= bytes.length; offset++) {
      // 2-byte Little-Endian & Big-Endian
      int s2le = bytes[offset] | (bytes[offset + 1] << 8);
      int s2be = (bytes[offset] << 8) | bytes[offset + 1];
      
      if (s2le > 0 && s2le < 200000) {
        extractedSteps = s2le;
      } else if (s2be > 0 && s2be < 200000) {
        extractedSteps = s2be;
      }

      // 4-byte Little-Endian & Big-Endian
      if (offset + 4 <= bytes.length) {
        int s4le = bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24);
        int s4be = (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
        if (s4le > 0 && s4le < 200000) { extractedSteps = s4le; break; }
        if (s4be > 0 && s4be < 200000) { extractedSteps = s4be; break; }
      }
      if (extractedSteps > 0 && isStepCmd) break;
    }

    if (extractedSteps > 0) {
      ref.read(stepsSupportedProvider.notifier).state = true;
      _saveAndPush({'steps': extractedSteps});
      return;
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
    _writeCharacteristics.clear();

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
    ref.read(stepsSupportedProvider.notifier).state = true;
    state = WatchState();

    // Stop foreground service - watch disconnected
    WatchForegroundService().stop().catchError((_) => null);
  }
}
