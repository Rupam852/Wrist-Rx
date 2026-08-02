import 'dart:convert';

/// ⌚ Wrist Rx Custom Smartwatch Companion Protocol Driver
/// Interacts directly with the custom WristRx Prototype Firmware (`firmware.cpp`)
class WristRxCustomWatchDriver {
  static const String serviceUuid = '00007777-0000-1000-8000-00805f9b34fb';
  static const String telemetryCharUuid = '00007778-0000-1000-8000-00805f9b34fb';
  static const String commandCharUuid = '00007779-0000-1000-8000-00805f9b34fb';

  /// Parses 10-byte binary telemetry packet from custom smartwatch:
  /// [0] = 0x77 Magic Byte
  /// [1..2] = Steps (16-bit)
  /// [3] = Heart Rate
  /// [4] = Systolic BP
  /// [5] = Diastolic BP
  /// [6] = SpO2 %
  /// [7] = Battery %
  /// [8] = Charging Flag
  static Map<String, dynamic>? parseTelemetryPacket(List<int> bytes) {
    if (bytes.length < 9) return null;
    if (bytes[0] != 0x77) return null;

    final steps = bytes[1] | (bytes[2] << 8);
    final heartRate = bytes[3];
    final systolic = bytes[4];
    final diastolic = bytes[5];
    final spo2 = bytes[6];
    final battery = bytes[7];
    final isCharging = bytes[8] == 1;

    return {
      'steps': steps,
      'heartRate': heartRate,
      'systolic': systolic,
      'diastolic': diastolic,
      'spo2': spo2,
      'battery': battery,
      'isCharging': isCharging,
    };
  }

  /// Builds Medicine Reminder alert packet for custom watch
  static List<int> buildMedicineReminderPacket(String medicineName) {
    final textBytes = utf8.encode(medicineName.take(16));
    return [0x01, ...textBytes];
  }

  /// Builds 1-Tap SOS Emergency alert packet for custom watch
  static List<int> buildSosAlertPacket() {
    return [0x02, 0x53, 0x4F, 0x53]; // "SOS"
  }

  /// Builds Time Sync packet for custom watch
  static List<int> buildTimeSyncPacket() {
    final now = DateTime.now();
    return [
      0x93,
      now.year & 0xFF,
      (now.year >> 8) & 0xFF,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    ];
  }
}

extension StringTake on String {
  String take(int n) => length > n ? substring(0, n) : this;
}
