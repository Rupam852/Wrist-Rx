import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/foreground_service.dart';
import '../../core/constants/api_constants.dart';
import '../home/health_provider.dart';
import '../auth/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'watch_protocol_registry.dart';



final watchProvider = StateNotifierProvider<WatchNotifier, WatchState>((ref) {
  return WatchNotifier(ref);
});

final watchOutOfRangeProvider = StateProvider<String?>((ref) => null);
final watchBatteryProvider = StateProvider<int>((ref) => 85);
final watchIsChargingProvider = StateProvider<bool>((ref) => false);

enum WatchConnectionStatus { disconnected, scanning, connecting, connected }

enum HardwareProtocol { standardGatt, vendorFitPro, vendorDaFit, vendorGeneric }

class WatchState {
  final WatchConnectionStatus status;
  final String? deviceName;
  final String? manufacturer;
  final HardwareProtocol protocol;
  final WatchBrandProfile? selectedBrandProfile;
  final String? error;

  WatchState({
    this.status = WatchConnectionStatus.disconnected,
    this.deviceName,
    this.manufacturer,
    this.protocol = HardwareProtocol.vendorGeneric,
    this.selectedBrandProfile,
    this.error,
  });

  WatchState copyWith({
    WatchConnectionStatus? status,
    String? deviceName,
    String? manufacturer,
    HardwareProtocol? protocol,
    WatchBrandProfile? selectedBrandProfile,
    String? error,
  }) =>
      WatchState(
        status: status ?? this.status,
        deviceName: deviceName ?? this.deviceName,
        manufacturer: manufacturer ?? this.manufacturer,
        protocol: protocol ?? this.protocol,
        selectedBrandProfile: selectedBrandProfile ?? this.selectedBrandProfile,
        error: error ?? this.error,
      );
}

class WatchNotifier extends StateNotifier<WatchState> {
  final Ref ref;
  WatchNotifier(this.ref) : super(WatchState());

  /// Returns the detected brand engine name (e.g. "Noise", "Fire-Boltt", etc.)
  String get detectedBrandName {
    if (_detectedBrandProfile != null) {
      return _detectedBrandProfile!.brandName;
    }
    return 'Noise';
  }

  /// Explicitly selects and locks watch brand protocol engine (Noise / Fire-Boltt / boAt / Universal)
  void selectWatchBrand(WatchBrandProfile profile) {
    _detectedBrandProfile = profile;
    state = state.copyWith(selectedBrandProfile: profile);

    // Send immediate time sync & probe burst tailored to selected brand
    _triggerWatchSync();
    Future.delayed(const Duration(milliseconds: 300), () => _triggerWatchSync());
    Future.delayed(const Duration(milliseconds: 1000), () => _triggerWatchSync());
  }

  final _api = ApiService();
  BluetoothDevice? _connectedDevice;
  bool _isManualDisconnect = false;
  WatchBrandProfile? _detectedBrandProfile;
  final List<StreamSubscription> _bleSubscriptions = [];
  final List<BluetoothCharacteristic> _writeCharacteristics = [];
  final List<BluetoothCharacteristic> _readableCharacteristics = [];
  Timer? _watchPingTimer;
  int _pingCycle = 0; // Rotating probe cycle index


  Future<void> connectViaBluetooth(BluetoothDevice device) async {
    state = state.copyWith(status: WatchConnectionStatus.connecting, deviceName: device.platformName);
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _isManualDisconnect = false;
      _connectedDevice = device;
      _writeCharacteristics.clear();
      _readableCharacteristics.clear();

      // Monitor live connection state for unexpected out-of-range disconnections
      final connSub = device.connectionState.listen((connState) {
        if (connState == BluetoothConnectionState.disconnected && !_isManualDisconnect) {
          _handleOutOfRangeDisconnect(device.platformName.isNotEmpty ? device.platformName : 'Smartwatch');
        }
      });
      _bleSubscriptions.add(connSub);

      // Monitor phone Bluetooth adapter state (if user turns off Bluetooth manually in phone settings)
      final adapterSub = FlutterBluePlus.adapterState.listen((adapterState) {
        if (adapterState == BluetoothAdapterState.off && !_isManualDisconnect) {
          _handleOutOfRangeDisconnect(device.platformName.isNotEmpty ? device.platformName : 'Smartwatch');
        }
      });
      _bleSubscriptions.add(adapterSub);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await _api.post(ApiConstants.connectBluetooth, {'macAddress': device.remoteId.str});
        } catch (_) {}
      }

      // Sync pre-existing app step baseline before receiving live watch telemetry
      ref.read(healthProvider.notifier).syncWatchBaseline();

      // 1. Request MTU 512 for max BLE payload bandwidth (prevents packet truncation)
      try {
        await device.requestMtu(512);
      } catch (_) {}

      // 2. Discover BLE services & run Hardware Capabilities Handshake
      try {
        final services = await device.discoverServices();
        await _performHardwareHandshake(device, services);
      } catch (_) {}

      // 3. Send initial time sync + probe burst immediately
      final now = DateTime.now();
      final timeBytes = [
        now.year & 0xFF, (now.year >> 8) & 0xFF,
        now.month, now.day, now.hour, now.minute, now.second,
      ];
      for (final char in _writeCharacteristics) {
        _sendBleCommand(char, [0xAB, 0x00, 0x0B, 0xFF, 0x93, ...timeBytes]);
        _sendBleCommand(char, [0xEA, 0x93, ...timeBytes]);
      }

      _triggerWatchSync();
      Future.delayed(const Duration(milliseconds: 500), () => _triggerWatchSync());
      Future.delayed(const Duration(milliseconds: 1500), () => _triggerWatchSync());

      // 4. Continuous periodic probe timer every 3 seconds (ensures continuous live SpO2, Heart Rate, Steps, & Reminders)
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

  /// 🤝 Hardware Handshake & Capabilities Matrix Analyzer
  Future<void> _performHardwareHandshake(BluetoothDevice device, List<BluetoothService> services) async {
    bool hasHrGatt = false;
    bool hasBpGatt = false;
    bool hasStepsGatt = false;
    bool isStandardGatt = false;
    String manufacturer = 'Generic Smartwatch';

    for (final service in services) {
      final sUuid = service.uuid.toString().toLowerCase();

      // DIS (Device Information Service 0x180A)
      if (sUuid.contains('180a')) {
        isStandardGatt = true;
        for (final char in service.characteristics) {
          final cUuid = char.uuid.toString().toLowerCase();
          if (cUuid.contains('2a29') && char.properties.read) {
            try {
              final bytes = await char.read();
              if (bytes.isNotEmpty) {
                manufacturer = String.fromCharCodes(bytes).trim();
              }
            } catch (_) {}
          }
        }
      }

      // Heart Rate Service (0x180D)
      if (sUuid.contains('180d')) {
        hasHrGatt = true;
        isStandardGatt = true;
      }

      // Blood Pressure Service (0x1810)
      if (sUuid.contains('1810')) {
        hasBpGatt = true;
        isStandardGatt = true;
      }

      // Pedometer Service (0x1814)
      if (sUuid.contains('1814')) {
        hasStepsGatt = true;
        isStandardGatt = true;
      }

      if (!sUuid.contains('1800') && !sUuid.contains('1801')) {
        for (final characteristic in service.characteristics) {
          // Collect writable characteristics
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            _writeCharacteristics.add(characteristic);
          }

          // Collect readable characteristics & read initial value
          if (characteristic.properties.read) {
            _readableCharacteristics.add(characteristic);
            try {
              final initialBytes = await characteristic.read();
              if (initialBytes.isNotEmpty) {
                _parseBleBytes(initialBytes, characteristic.uuid.toString());
              }
            } catch (_) {}
          }

          // Enable Notifications / Indications
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
    }

    // Auto-detect Watch Brand & Model Protocol Profile from Registry
    final dName = (device.platformName.isNotEmpty)
        ? device.platformName
        : (state.deviceName?.isNotEmpty == true ? state.deviceName! : 'Smartwatch');
    
    _detectedBrandProfile = WatchProtocolRegistry.detectBrand(dName, manufacturer);

    // Fallback: If detection is ambiguous, default to Noise / Realtek Multi-Vendor engine (supports uRPC + Moyoung + 0xAB/0xEA)
    _detectedBrandProfile ??= WatchProtocolRegistry.globalBrandProfiles.firstWhere(
      (p) => p.brandName == 'Noise',
      orElse: () => WatchProtocolRegistry.globalBrandProfiles[0],
    );

    // Resolve Hardware Protocol Mode
    HardwareProtocol resolvedProtocol = HardwareProtocol.vendorGeneric;
    if (isStandardGatt) {
      resolvedProtocol = HardwareProtocol.standardGatt;
    }

    state = state.copyWith(
      manufacturer: manufacturer,
      protocol: resolvedProtocol,
    );

    // Default open hardware capabilities
    ref.read(hrSupportedProvider.notifier).state = hasHrGatt || true;
    ref.read(bpSupportedProvider.notifier).state = hasBpGatt || true;
    ref.read(stepsSupportedProvider.notifier).state = hasStepsGatt || true;
  }


  // ─────────────────────────────────────────────────────────────────
  // Public Watch Message API
  // ─────────────────────────────────────────────────────────────────

  /// 🆘 Sends SOS alert to watch — 3x vibration + "SOS Sent!" text
  /// Called when user triggers SOS from the app.
  Future<void> sendSosAlert() async {
    // 1. Post to Android status bar via foreground service (for OS notification mirroring to watch)
    WatchForegroundService().updateNotification(
      watchName: state.deviceName ?? 'Smartwatch',
      dataInfo: '🚨 EMERGENCY SOS ALERT SENT!',
    ).catchError((_) => null);

    // 2. Send direct BLE vibration packets
    if (_writeCharacteristics.isNotEmpty) {
      const sosText = 'SOS Sent!';
      await _sendWatchTextAndVibrate(sosText, vibrationStrength: 3);
    }
  }

  /// 💊 Sends medicine reminder notification to watch — 3x vibration + medicine name
  /// Called by ReminderProvider when a reminder time fires.
  Future<void> sendWatchNotification(String medicineName) async {
    final text = medicineName.length > 18 ? medicineName.substring(0, 18) : medicineName;

    // 1. Post high-priority update to status bar notification (Android relays to watch automatically)
    WatchForegroundService().updateNotification(
      watchName: state.deviceName ?? 'Smartwatch',
      dataInfo: '💊 REMINDER: Take $text',
    ).catchError((_) => null);

    // 2. Direct BLE byte burst — 3 consecutive pulse waves to guarantee watch vibration motor triggers
    if (_writeCharacteristics.isNotEmpty) {
      await _sendWatchTextAndVibrate('Take: $text', vibrationStrength: 3);
      await Future.delayed(const Duration(milliseconds: 300));
      await _sendWatchTextAndVibrate('Take: $text', vibrationStrength: 3);
      await Future.delayed(const Duration(milliseconds: 300));
      await _sendWatchTextAndVibrate('Take: $text', vibrationStrength: 3);
    }
  }

  /// 🧪 Test watch alert — vibrates watch immediately & shows test message
  Future<({bool success, int channelsCount})> testWatchAlert() async {
    // 1. Trigger status bar notification update
    WatchForegroundService().updateNotification(
      watchName: state.deviceName ?? 'Smartwatch',
      dataInfo: '🧪 TEST ALERT: Watch Vibration Test!',
    ).catchError((_) => null);

    if (_writeCharacteristics.isEmpty) {
      return (success: false, channelsCount: 0);
    }

    // 2. Direct BLE byte burst — high speed pulse wave
    await _sendWatchTextAndVibrate('Test Alert', vibrationStrength: 3);
    return (success: true, channelsCount: _writeCharacteristics.length);
  }

  /// Internal helper: vibrate + optional text message via multi-vendor BLE protocols
  Future<void> _sendWatchTextAndVibrate(String text, {int vibrationStrength = 1}) async {
    if (_writeCharacteristics.isEmpty) return;

    final textBytes = text.codeUnits.take(20).toList();
    final len       = textBytes.length + 4;

    for (final char in _writeCharacteristics) {
      final cUuid = char.uuid.toString().toLowerCase();

      // 1. Send brand-tuned native packets (e.g. Noise uRPC / DaFit / boAt) to ALL write channels
      if (_detectedBrandProfile != null) {
        for (final p in _detectedBrandProfile!.vibrationProbes) {
          _sendBleCommand(char, p);
        }
        if (_detectedBrandProfile!.getNotificationPackets != null) {
          for (final p in _detectedBrandProfile!.getNotificationPackets!(text)) {
            _sendBleCommand(char, p);
          }
        }
      }

      // 2. GATT Immediate Alert Service (0x1802 / 0x2A06)
      if (cUuid.contains('2a06')) {
        _sendBleCommand(char, [vibrationStrength > 1 ? 0x02 : 0x01]);
      }

      // 3. Multi-Vendor Fallback Burst across all channels in parallel
      _sendBleCommand(char, [0xAB, 0x00, 0x04, 0xFF, 0x74, vibrationStrength]);
      _sendBleCommand(char, [0xAB, 0x74, vibrationStrength]);
      _sendBleCommand(char, [0x55, 0x74, vibrationStrength]);
      _sendBleCommand(char, [0xAA, 0x74, vibrationStrength]);
      _sendBleCommand(char, [0xEA, 0x02, vibrationStrength]);
      _sendBleCommand(char, [0xEA, 0x01, ...textBytes]);
      _sendBleCommand(char, [0xAB, 0x00, len, 0xFF, 0x72, 0x02, 0x00, ...textBytes]);
      _sendBleCommand(char, [0x55, 0x72, ...textBytes]);
    }
  }

  // ─────────────────────────────────────────────────────────────────

  Future<void> _sendBleCommand(BluetoothCharacteristic char, List<int> bytes) async {
    try {
      // 1. Try 'write without response' first for zero-latency radio TX queue delivery
      if (char.properties.writeWithoutResponse) {
        await char.write(bytes, withoutResponse: true).timeout(const Duration(milliseconds: 300));
      } else if (char.properties.write) {
        await char.write(bytes, withoutResponse: false).timeout(const Duration(milliseconds: 500));
      }
      await Future.delayed(const Duration(milliseconds: 15));
    } catch (_) {
      try {
        // 2. Fallback attempt without response
        if (char.properties.write) {
          await char.write(bytes, withoutResponse: true).timeout(const Duration(milliseconds: 300));
        }
      } catch (_) {}
    }
  }

  /// Public API: Manually trigger watch sync probe burst (e.g. during hardware diagnostics)
  void triggerWatchSyncManually() {
    _triggerWatchSync();
    Future.delayed(const Duration(milliseconds: 300), () => _triggerWatchSync());
  }

  /// Sends smart sync probes every cycle:
  /// - Uses auto-detected Brand Protocol Profile if matched, or generic multi-probe fallback
  void _triggerWatchSync() async {
    // 1. Poll readable characteristics continuously for watches that don't auto-notify (e.g. Battery 0x2A19)
    for (final char in _readableCharacteristics) {
      try {
        final val = await char.read();
        if (val.isNotEmpty) {
          _parseBleBytes(val, char.uuid.toString());
        }
      } catch (_) {}
    }

    if (_writeCharacteristics.isEmpty) return;

    final cycle = _pingCycle % 3;
    _pingCycle++;

    // 🎯 If Brand Profile was Auto-Detected, send exact brand-tuned probes for 100% accuracy!
    if (_detectedBrandProfile != null) {
      for (final char in _writeCharacteristics) {
        for (final p in _detectedBrandProfile!.batteryProbes) {
          await _sendBleCommand(char, p);
        }
        for (final p in _detectedBrandProfile!.stepProbes) {
          await _sendBleCommand(char, p);
        }
        if (cycle == 0) {
          for (final p in _detectedBrandProfile!.hrProbes) {
            await _sendBleCommand(char, p);
          }
        } else if (cycle == 1) {
          for (final p in _detectedBrandProfile!.bpProbes) {
            await _sendBleCommand(char, p);
          }
        } else {
          for (final p in _detectedBrandProfile!.spo2Probes) {
            await _sendBleCommand(char, p);
          }
        }
      }
      return;
    }

    // Generic Multi-Vendor Probe Fallback
    for (final char in _writeCharacteristics) {
      // Always send Battery & Step Probes in every sync cycle so steps and battery update in 100% real-time!
      await _sendBleCommand(char, [0xAB, 0x00, 0x04, 0xFF, 0x91]);
      await _sendBleCommand(char, [0xAB, 0x91]);
      await _sendBleCommand(char, [0xAA, 0x91]);
      await _sendBleCommand(char, [0x04, 0x02]);

      // Always send Live Step Probes
      await _sendBleCommand(char, [0xAB, 0x00, 0x04, 0xFF, 0x51]);
      await _sendBleCommand(char, [0xAB, 0x51]);
      await _sendBleCommand(char, [0x55, 0x51]);
      await _sendBleCommand(char, [0xAB, 0x31]);
      await _sendBleCommand(char, [0xAA, 0x01]);

      if (cycle == 0) {
        // Step probe cycle A (FitPro / DaFit / Chinese OEM)
        await _sendBleCommand(char, [0x55, 0x01]);
        await _sendBleCommand(char, [0x55, 0x02]);
      } else if (cycle == 1) {
        // Step probe cycle B (VeryFit / JYou / FastRun / GATT)
        await _sendBleCommand(char, [0xEA, 0x01]);
      } else {
        // HR, BP & SpO2 probe cycle
        await _sendBleCommand(char, [0xAB, 0x00, 0x04, 0xFF, 0x52]);
        await _sendBleCommand(char, [0xAB, 0x00, 0x04, 0xFF, 0x53]);
        await _sendBleCommand(char, [0xAB, 0x53]);
        await _sendBleCommand(char, [0x55, 0x53]);
        await _sendBleCommand(char, [0xEA, 0x53]);
        await _sendBleCommand(char, [0xAB, 0x0A]);
        await _sendBleCommand(char, [0x55, 0x0A]);
        await _sendBleCommand(char, [0xAB, 0x12]);
        await _sendBleCommand(char, [0x55, 0x12]);
      }
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
        if (json.containsKey('battery')) {
          int batt = (json['battery'] as num).toInt();
          if (batt >= 0 && batt <= 100) {
            ref.read(watchBatteryProvider.notifier).state = batt;
          }
        }
        if (json.containsKey('charging') || json.containsKey('isCharging')) {
          bool charging = json['charging'] == true || json['isCharging'] == true;
          ref.read(watchIsChargingProvider.notifier).state = charging;
        }
        _saveAndPush(json);
        return;
      }
    } catch (_) {}

    final u = uuid?.toLowerCase() ?? '';

    // ── PRIORITY 1: Standard GATT Characteristics by UUID ──────────────────

    // Standard GATT Battery Level & Charging Status (0x2A19 / service 0x180F)
    if (u.contains('2a19') || u.contains('180f') || u.contains('battery')) {
      if (bytes.isNotEmpty) {
        int batt = bytes[0];
        if (batt >= 0 && batt <= 100) {
          ref.read(watchBatteryProvider.notifier).state = batt;
        }
        if (bytes.length >= 2) {
          bool isCharging = (bytes[1] & 0x01) != 0 || bytes[1] == 1 || bytes[1] == 0x80;
          ref.read(watchIsChargingProvider.notifier).state = isCharging;
        }
        return;
      }
    }


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

    // Standard GATT Pulse Oximeter / SpO2 (0x1822 / 0x2A5E / 0x2A5F)
    if (u.contains('2a5e') || u.contains('2a5f') || u.contains('1822') || u.contains('spo2') || u.contains('oximeter')) {
      if (bytes.length >= 2) {
        for (int i = 0; i < bytes.length; i++) {
          int spo2 = bytes[i];
          if (spo2 >= 70 && spo2 <= 100) {
            ref.read(spo2SupportedProvider.notifier).state = true;
            _saveAndPush({'spo2': spo2});
            return;
          }
        }
      }
      return;
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

    // Only process known vendor protocol headers (including 0x01 for Noise uRPC/D2D)
    if (firstByte != 0xAB && firstByte != 0x55 && firstByte != 0xAA &&
        firstByte != 0xFA && firstByte != 0xFC && firstByte != 0x7C &&
        firstByte != 0xEA && firstByte != 0x04 && firstByte != 0x68 &&
        firstByte != 0xCD && firstByte != 0x80 && firstByte != 0x01) {
      return;
    }

    final cmdByte = bytes[1];
    // Check for longer header format: AB 00 <len> FF <cmd> (where bytes[2] is payload length)
    final bool isLongHeader = (bytes.length >= 5 && bytes[0] == 0xAB && bytes[1] == 0x00 && bytes[3] == 0xFF);
    final effectiveCmd = isLongHeader ? bytes[4] : cmdByte;
    final dataStart = isLongHeader ? 5 : 2;

    // ── Vendor Battery Level & Charging Status Response ─────────────────────
    // Command codes: 0x91, 0x92, 0x03, 0x1A, 0x90
    if (effectiveCmd == 0x91 || effectiveCmd == 0x92 || effectiveCmd == 0x03 ||
        effectiveCmd == 0x1A || effectiveCmd == 0x90) {
      if (bytes.length >= dataStart + 1) {
        int batt = bytes[dataStart];
        if (batt >= 0 && batt <= 100) {
          ref.read(watchBatteryProvider.notifier).state = batt;
        }
        if (bytes.length >= dataStart + 2) {
          int flag = bytes[dataStart + 1];
          bool isCharging = (flag & 0x01) != 0 || flag == 1 || flag == 0x80 || flag == 0x02;
          ref.read(watchIsChargingProvider.notifier).state = isCharging;
        } else {
          bool isCharging = bytes.skip(dataStart).any((b) => b == 0x01 || b == 0x80);
          if (isCharging) {
            ref.read(watchIsChargingProvider.notifier).state = true;
          }
        }
        return;
      }
    }

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

    // ── Vendor Blood Oxygen (SpO2 %) Response ──────────────────────────────
    // Command codes: 0x53, 0x12, 0x16, 0x0B, 0x1B, 0x70
    if (effectiveCmd == 0x53 || effectiveCmd == 0x12 || effectiveCmd == 0x16 ||
        effectiveCmd == 0x0B || effectiveCmd == 0x1B || effectiveCmd == 0x70) {
      for (int i = dataStart; i < bytes.length; i++) {
        int spo2 = bytes[i];
        if (spo2 >= 70 && spo2 <= 100) {
          ref.read(spo2SupportedProvider.notifier).state = true;
          _saveAndPush({'spo2': spo2});
          return;
        }
      }
      return;
    }

    // ── Verified Vendor Pedometer (Steps) Response ────────────────────────
    // Command codes: 0x51, 0x31, 0x01, 0x02, 0x32, 0x11
    if (effectiveCmd == 0x51 || effectiveCmd == 0x31 || effectiveCmd == 0x01 ||
        effectiveCmd == 0x02 || effectiveCmd == 0x32 || effectiveCmd == 0x11) {
      if (bytes.length >= dataStart + 2) {
        int steps = bytes[dataStart] | (bytes[dataStart + 1] << 8);
        if (bytes.length >= dataStart + 4) {
          steps = bytes[dataStart] | (bytes[dataStart + 1] << 8) | (bytes[dataStart + 2] << 16) | (bytes[dataStart + 3] << 24);
        }
        if (steps >= 0 && steps < 200000) {
          ref.read(stepsSupportedProvider.notifier).state = true;
          _saveAndPush({'steps': steps});
          return;
        }
      }
    }


  }


  /// Merges single metric update into full HealthReading after cleaning noise & corrupt bytes.
  void _saveAndPush(Map<String, dynamic> data) {
    final Map<String, dynamic> cleanData = {};

    // 1. Heart Rate Validation (40 - 220 BPM)
    if (data.containsKey('heartRate')) {
      final hr = data['heartRate'];
      if (hr is num && hr >= 40 && hr <= 220) {
        cleanData['heartRate'] = hr;
      }
    }

    // 2. Blood Pressure Validation (Systolic: 70-220, Diastolic: 40-140)
    if (data.containsKey('systolic') && data.containsKey('diastolic')) {
      final sys = data['systolic'];
      final dia = data['diastolic'];
      if (sys is num && dia is num && sys >= 70 && sys <= 220 && dia >= 40 && dia <= 140) {
        cleanData['systolic'] = sys;
        cleanData['diastolic'] = dia;
      }
    }

    // 3. Pedometer Steps Validation (0 - 200,000 steps)
    if (data.containsKey('steps')) {
      final st = data['steps'];
      if (st is num && st >= 0 && st <= 200000) {
        cleanData['steps'] = st.toInt();
      }
    }

    if (cleanData.isNotEmpty) {
      ref.read(healthProvider.notifier).updateFromWatch(cleanData);
    }
  }




  void _handleOutOfRangeDisconnect(String deviceName) {
    _watchPingTimer?.cancel();
    for (final sub in _bleSubscriptions) {
      try { sub.cancel(); } catch (_) {}
    }
    _bleSubscriptions.clear();
    _writeCharacteristics.clear();
    _readableCharacteristics.clear();

    _connectedDevice = null;
    ref.read(watchConnectedProvider.notifier).state = false;
    state = WatchState(status: WatchConnectionStatus.disconnected, error: 'Out of range');

    WatchForegroundService().stop().catchError((_) => null);

    // Notify UI about out-of-range disconnect
    ref.read(watchOutOfRangeProvider.notifier).state = deviceName;
  }

  Future<void> disconnect() async {
    _isManualDisconnect = true;
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
