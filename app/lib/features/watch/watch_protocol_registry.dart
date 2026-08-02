import 'dart:convert';

/// 🌐 Global Smartwatch Brand & Model Protocol Database Registry
/// Maps every major smartwatch brand and OEM chipset worldwide to their exact BLE protocol probes & capabilities.

class WatchBrandProfile {
  final String brandName;
  final List<String> namePrefixes;
  final List<int> headerBytes;
  final List<List<int>> stepProbes;
  final List<List<int>> hrProbes;
  final List<List<int>> bpProbes;
  final List<List<int>> batteryProbes;
  final List<List<int>> spo2Probes;
  final List<List<int>> vibrationProbes;
  final List<List<int>> Function(String text)? getNotificationPackets;

  const WatchBrandProfile({
    required this.brandName,
    required this.namePrefixes,
    required this.headerBytes,
    required this.stepProbes,
    required this.hrProbes,
    required this.bpProbes,
    required this.batteryProbes,
    this.spo2Probes = const [],
    this.vibrationProbes = const [],
    this.getNotificationPackets,
  });
}

class WatchProtocolRegistry {
  static List<WatchBrandProfile> globalBrandProfiles = [
    // 0. WristRx Custom Smartwatch (Prototype Hardware Engine)
    WatchBrandProfile(
      brandName: 'WristRx Custom Watch',
      namePrefixes: ['wristrx', 'prototype', 'custom'],
      headerBytes: [0x77],
      stepProbes: [
        [0x77, 0x01],
      ],
      hrProbes: [
        [0x77, 0x0A],
      ],
      bpProbes: [
        [0x77, 0x52],
      ],
      batteryProbes: [
        [0x77, 0x91],
      ],
      spo2Probes: [
        [0x77, 0x53],
      ],
      vibrationProbes: [
        [0x01, 0x56, 0x49, 0x42],
      ],
    ),

    // 1. Fire-Boltt (Ninja, Ring, Phoenix, Hurricane, Invincible, Vision, Dazzle, Talk, Cobra, Supernova) — DaFit Protocol Engine
    WatchBrandProfile(
      brandName: 'Fire-Boltt',
      namePrefixes: ['fire', 'boltt', 'ninja', 'ring', 'phoenix', 'invincible', 'vision', 'dazzle', 'talk', 'cobra', 'dafit'],
      headerBytes: [0xAB, 0x55, 0xAA, 0xCD, 0xEA],
      stepProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x51],
        [0xAB, 0x51],
        [0x55, 0x51],
        [0xEA, 0x01],
      ],
      hrProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x0A],
        [0xAB, 0x0A],
        [0x55, 0x0A],
        [0xEA, 0x0A],
      ],
      bpProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x52],
        [0xAB, 0x52],
        [0xEA, 0x52],
      ],
      batteryProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x91],
        [0xAB, 0x91],
        [0xAA, 0x91],
        [0xEA, 0x91],
      ],
      spo2Probes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x53],
        [0xAB, 0x53],
        [0xEA, 0x53],
      ],
      vibrationProbes: [
        [0xEA, 0x02, 0x02],
        [0xAB, 0x00, 0x04, 0xFF, 0x74, 0x02],
        [0xAB, 0x74, 0x02],
        [0x55, 0x74, 0x02],
      ],
      getNotificationPackets: (text) {
        final b = text.codeUnits.take(20).toList();
        final len = b.length + 4;
        return [
          [0xEA, 0x01, 0x01, ...b],
          [0xAB, 0x00, len, 0xFF, 0x72, 0x02, 0x00, ...b],
          [0xAB, 0x72, 0x01, ...b],
          [0x55, 0x72, ...b],
        ];
      },
    ),

    // 2. boAt (Wave, Storm, Xtend, Lunar, Enigma, Primia, Matrix, Cosmos) — boAt Wearables Engine
    WatchBrandProfile(
      brandName: 'boAt',
      namePrefixes: ['boat', 'wave', 'storm', 'xtend', 'lunar', 'enigma', 'primia', 'matrix', 'flash', 'ultima'],
      headerBytes: [0xAB, 0x55, 0xCD, 0xFA, 0xEA],
      stepProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x31],
        [0xAB, 0x31],
        [0x55, 0x01],
        [0xEA, 0x01],
      ],
      hrProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x0A],
        [0xAB, 0x0A],
        [0xEA, 0x0A],
      ],
      bpProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x52],
        [0xAB, 0x52],
        [0xEA, 0x52],
      ],
      batteryProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x91],
        [0xAB, 0x91],
        [0x04, 0x02],
        [0xEA, 0x91],
      ],
      spo2Probes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x53],
        [0xAB, 0x53],
        [0xEA, 0x53],
      ],
      vibrationProbes: [
        [0xEA, 0x02, 0x02],
        [0xAB, 0x00, 0x04, 0xFF, 0x74, 0x02],
        [0xAB, 0x74, 0x02],
        [0xAA, 0x74, 0x02],
      ],
      getNotificationPackets: (text) {
        final b = text.codeUnits.take(20).toList();
        final len = b.length + 4;
        return [
          [0xEA, 0x01, 0x01, ...b],
          [0xAB, 0x00, len, 0xFF, 0x72, 0x02, 0x00, ...b],
          [0xAB, 0x72, 0x01, ...b],
          [0x55, 0x72, ...b],
        ];
      },
    ),

    // 3. Noise (ColorFit, Pulse, Evolve, Fit, Loop, Icon, Turbo) — RT-Thread OS uRPC & Realtek Engine
    WatchBrandProfile(
      brandName: 'Noise',
      namePrefixes: ['noise', 'colorfit', 'pulse', 'evolve', 'loop', 'icon', 'turbo', 'color fit'],
      headerBytes: [0xAB, 0x55, 0xEA, 0xFC, 0x01],
      stepProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x51],
        [0xAB, 0x51],
        [0x55, 0x51],
        [0x55, 0x01],
        [0x55, 0x02],
        [0xEA, 0x01],
        [0xAB, 0x31],
        [0x01, 0x01, 0x00, 0x01, 0x14, 0x01], // uRPC system_data_sync
      ],
      hrProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x0A],
        [0xAB, 0x0A],
        [0xEA, 0x0A],
        [0x55, 0x0A],
      ],
      bpProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x52],
        [0xAB, 0x52],
        [0xEA, 0x52],
      ],
      batteryProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x91],
        [0xAB, 0x91],
        [0xAB, 0x03],
        [0xEA, 0x91],
        [0x01, 0x01, 0x00, 0x02, 0x14, 0x01], // uRPC service_settings_get
      ],
      spo2Probes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x53],
        [0xAB, 0x53],
        [0x55, 0x53],
        [0xEA, 0x53],
        [0xAB, 0x12],
        [0x55, 0x12],
        [0x01, 0x01, 0x00, 0x03, 0x14, 0x01],
      ],
      vibrationProbes: [
        NoiseUrpcDriver.buildVibrationPacket(),
        [0xAB, 0x00, 0x04, 0xFF, 0x74, 0x02],
        [0xEA, 0x02, 0x02],
        [0xAB, 0x74, 0x02],
        [0x55, 0x74, 0x02],
      ],
      getNotificationPackets: (text) {
        final b = text.codeUnits.take(20).toList();
        final len = b.length + 4;
        return [
          NoiseUrpcDriver.buildNotificationPushPacket(text),
          [0xEA, 0x01, 0x01, ...b],
          [0xAB, 0x00, len, 0xFF, 0x72, 0x02, 0x00, ...b],
          [0x55, 0x72, ...b],
          [0xAB, 0x72, 0x01, ...b],
        ];
      },
    ),

    // 4. Fastrack (Revoltt, Reflex, Limitless, Glide, Optimus)
    WatchBrandProfile(
      brandName: 'Fastrack',
      namePrefixes: ['fastrack', 'revoltt', 'reflex', 'limitless', 'glide', 'optimus'],
      headerBytes: [0xAB, 0x55],
      stepProbes: [
        [0xAB, 0x51],
      ],
      hrProbes: [
        [0xAB, 0x0A],
      ],
      bpProbes: [
        [0xAB, 0x52],
      ],
      batteryProbes: [
        [0xAB, 0x91],
      ],
      vibrationProbes: [
        [0xAB, 0x74, 0x02],
        [0x55, 0x74, 0x02],
      ],
      getNotificationPackets: (text) {
        final b = text.codeUnits.take(20).toList();
        return [
          [0xAB, 0x72, 0x01, ...b],
          [0x55, 0x72, ...b],
        ];
      },
    ),

    // 5. Boult (Rover, Crown, Drift, Striker, Mirage, Cosmic)
    WatchBrandProfile(
      brandName: 'Boult',
      namePrefixes: ['boult', 'rover', 'crown', 'drift', 'striker', 'mirage', 'cosmic'],
      headerBytes: [0xAB, 0xAA],
      stepProbes: [
        [0xAB, 0x51],
      ],
      hrProbes: [
        [0xAB, 0x0A],
      ],
      bpProbes: [
        [0xAB, 0x52],
      ],
      batteryProbes: [
        [0xAB, 0x91],
      ],
      vibrationProbes: [
        [0xAB, 0x74, 0x02],
        [0xAA, 0x74, 0x02],
      ],
      getNotificationPackets: (text) {
        final b = text.codeUnits.take(20).toList();
        return [
          [0xAB, 0x72, 0x01, ...b],
        ];
      },
    ),

    // 6. Pebble (Cosmos, Spectra, Pace, Venus, Frost, Hive)
    WatchBrandProfile(
      brandName: 'Pebble',
      namePrefixes: ['pebble', 'cosmos', 'spectra', 'pace', 'venus', 'frost'],
      headerBytes: [0xAB, 0x55],
      stepProbes: [
        [0xAB, 0x51],
      ],
      hrProbes: [
        [0xAB, 0x0A],
      ],
      bpProbes: [
        [0xAB, 0x52],
      ],
      batteryProbes: [
        [0xAB, 0x91],
      ],
      vibrationProbes: [
        [0xAB, 0x74, 0x02],
      ],
      getNotificationPackets: (text) {
        final b = text.codeUnits.take(20).toList();
        return [
          [0xAB, 0x72, 0x01, ...b],
        ];
      },
    ),

    // 7. FitPro / T500 / Ultra 8 / S8 Ultra / Chinese Clones (Qube, ZL02, Y20, D20)
    WatchBrandProfile(
      brandName: 'FitPro / Chinese Smartwatch',
      namePrefixes: ['fitpro', 't500', 'ultra', 'qube', 'zl02', 'y20', 'd20', 'watch8', 's8', 'i8', 'smart', 'hryfine', 'lefun'],
      headerBytes: [0xAB, 0xCD, 0xEA, 0xAA, 0x55],
      stepProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x51],
        [0xAB, 0x51],
        [0xCD, 0x01],
        [0xAA, 0x01],
      ],
      hrProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x0A],
        [0xAB, 0x0A],
        [0xCD, 0x0A],
      ],
      bpProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x52],
        [0xAB, 0x52],
      ],
      batteryProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x91],
        [0xAB, 0x91],
        [0xAA, 0x91],
      ],
      vibrationProbes: [
        [0xAB, 0x00, 0x04, 0xFF, 0x74, 0x02],
        [0xAB, 0x74, 0x02],
        [0xAB, 0x00, 0x05, 0xFF, 0x72, 0x01, 0x01],
      ],
      getNotificationPackets: (text) {
        final b = text.codeUnits.take(20).toList();
        final len = b.length + 4;
        return [
          [0xAB, 0x00, len, 0xFF, 0x72, 0x02, 0x00, ...b],
          [0xAB, 0x72, 0x01, ...b],
        ];
      },
    ),

    // 8. Xiaomi / Redmi / Amazfit / Zepp OS
    WatchBrandProfile(
      brandName: 'Xiaomi / Amazfit',
      namePrefixes: ['xiaomi', 'mi', 'redmi', 'amazfit', 'bip', 'gtr', 'gts', 'band'],
      headerBytes: [0xAB, 0x55, 0xFE],
      stepProbes: [
        [0xAB, 0x51],
      ],
      hrProbes: [
        [0xAB, 0x0A],
      ],
      bpProbes: [
        [0xAB, 0x52],
      ],
      batteryProbes: [
        [0xAB, 0x91],
      ],
      vibrationProbes: [
        [0x02], // GATT Alert Level 0x2A06 (High Alert)
        [0xAB, 0x74, 0x02],
      ],
      getNotificationPackets: (text) {
        final b = text.codeUnits.take(20).toList();
        return [
          [0x01, 0x01, ...b], // GATT New Alert Service 0x1811 / 0x2A46
          [0xAB, 0x72, 0x01, ...b],
        ];
      },
    ),

    // 9. Realme Watch / Huawei / Honor
    WatchBrandProfile(
      brandName: 'Realme / Huawei',
      namePrefixes: ['realme', 'huawei', 'honor', 'magic', 'fit'],
      headerBytes: [0xAB, 0x55],
      stepProbes: [
        [0xAB, 0x51],
      ],
      hrProbes: [
        [0xAB, 0x0A],
      ],
      bpProbes: [
        [0xAB, 0x52],
      ],
      batteryProbes: [
        [0xAB, 0x91],
      ],
      vibrationProbes: [
        [0x02],
        [0xAB, 0x74, 0x02],
      ],
      getNotificationPackets: (text) {
        final b = text.codeUnits.take(20).toList();
        return [
          [0x01, 0x01, ...b],
          [0xAB, 0x72, 0x01, ...b],
        ];
      },
    ),
  ];

  /// Detects matching watch brand profile from device platform name or DIS manufacturer string
  static WatchBrandProfile? detectBrand(String deviceName, [String? manufacturer]) {
    final nameLower = deviceName.toLowerCase();
    final mfgLower = manufacturer?.toLowerCase() ?? '';

    for (final profile in globalBrandProfiles) {
      for (final prefix in profile.namePrefixes) {
        if (nameLower.contains(prefix) || mfgLower.contains(prefix)) {
          return profile;
        }
      }
    }
    return null;
  }
}

/// ⚡ Native Noise RT-Thread uRPC & MCF Protocol Driver
/// Reverse-engineered directly from NoiseFit decompiled APK source code.
class NoiseUrpcDriver {
  static int _pktCounter = 0;

  /// Builds RT-Thread uRPC D2D "svc_notification_push" packet
  static List<int> buildNotificationPushPacket(String text, {String title = 'Wrist Rx'}) {
    _pktCounter = (_pktCounter + 1) % 256;

    final titleBytes = [...utf8.encode(title), 0];
    final senderBytes = [...utf8.encode('WristRx'), 0];
    final textBytes  = [...utf8.encode(text), 0];
    final msgTypeBytes = [...utf8.encode('msg'), 0];
    final waysBytes = [...utf8.encode('banner'), 0];

    // uRPC FFI Arguments
    final ffiArgs = <int>[
      ..._argArray(titleBytes),         // title
      ..._argArray([0]),                // icon_path
      ..._argArray(senderBytes),        // sender
      ..._argArray(textBytes),          // text_content
      ..._argArray([0]),                // image_context_path
      ..._argArray(msgTypeBytes),       // msg_type
      ..._argArray(waysBytes),          // presenting_ways
      ..._argU32(1),                    // priority = 1
      ..._argU32(DateTime.now().millisecondsSinceEpoch ~/ 1000), // timestamp
    ];

    final funcName = [... 'svc_notification_push'.codeUnits, 0];

    // Payload: [0x01 (FFI), func_name_str, ffiArgs]
    final payload = <int>[0x01, ...funcName, ...ffiArgs];

    // D2D Header: [src_id=1, dst_id=0, pkt_id, attr]
    // attr = (REQ=0 << 6) | (need_ack=0 << 5) | (need_rsp=1 << 4) | (priority=1 << 2) = 0x14
    final d2dHeader = <int>[0x01, 0x00, _pktCounter, 0x14];

    // TransPacket wrapper: [Type.D2D = 1, ...d2dHeader, ...payload]
    return [0x01, ...d2dHeader, ...payload];
  }

  /// Builds RT-Thread uRPC vibration alert packet
  static List<int> buildVibrationPacket() {
    _pktCounter = (_pktCounter + 1) % 256;
    final funcName = [... 'svc_alert_vibrate'.codeUnits, 0];
    final payload = <int>[0x01, ...funcName, ..._argU32(2)];
    final d2dHeader = <int>[0x01, 0x00, _pktCounter, 0x14];
    return [0x01, ...d2dHeader, ...payload];
  }

  static List<int> _argArray(List<int> bytes) {
    final len = bytes.length;
    return [
      0x81, // U8 | ARRAY (0x01 | 0x80)
      len & 0xFF,
      (len >> 8) & 0xFF,
      ...bytes,
    ];
  }

  static List<int> _argU32(int val) {
    return [
      0x04, // U32
      val & 0xFF,
      (val >> 8) & 0xFF,
      (val >> 16) & 0xFF,
      (val >> 24) & 0xFF,
    ];
  }
}
