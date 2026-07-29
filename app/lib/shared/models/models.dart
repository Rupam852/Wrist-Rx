class UserModel {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final bool isFirstLogin;
  final UserProfile profile;
  final UserSettings settings;
  final WatchInfo watchInfo;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl = '',
    this.isFirstLogin = true,
    required this.profile,
    required this.settings,
    required this.watchInfo,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      photoUrl: json['photoUrl'] ?? '',
      isFirstLogin: json['isFirstLogin'] ?? true,
      profile: UserProfile.fromJson(json['profile'] ?? {}),
      settings: UserSettings.fromJson(json['settings'] ?? {}),
      watchInfo: WatchInfo.fromJson(json['watchInfo'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': uid, 'name': name, 'email': email, 'photoUrl': photoUrl,
    'isFirstLogin': isFirstLogin,
  };

  UserModel copyWith({
    String? name, String? photoUrl, bool? isFirstLogin,
    UserProfile? profile, UserSettings? settings, WatchInfo? watchInfo,
  }) {
    return UserModel(
      uid: uid, email: email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      profile: profile ?? this.profile,
      settings: settings ?? this.settings,
      watchInfo: watchInfo ?? this.watchInfo,
    );
  }
}

class UserProfile {
  final int? age;
  final String? gender;
  final List<String> conditions;
  final List<String> goals;
  final String? activityLevel;

  UserProfile({this.age, this.gender, this.conditions = const [], this.goals = const [], this.activityLevel});

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    age: json['age'],
    gender: json['gender'],
    conditions: List<String>.from(json['conditions'] ?? []),
    goals: List<String>.from(json['goals'] ?? []),
    activityLevel: json['activityLevel'],
  );

  Map<String, dynamic> toJson() => {
    'age': age, 'gender': gender, 'conditions': conditions,
    'goals': goals, 'activityLevel': activityLevel,
  };
}

class UserSettings {
  final bool notifications;
  final bool sound;
  final bool haptic;
  final String aiProvider;
  final String aiModel;
  final List<EmergencyContact> emergencyContacts;

  UserSettings({
    this.notifications = true, this.sound = false, this.haptic = false,
    this.aiProvider = 'gemini', this.aiModel = 'gemini-2.0-flash',
    this.emergencyContacts = const [],
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
    notifications: json['notifications'] ?? true,
    sound: json['sound'] ?? false,
    haptic: json['haptic'] ?? false,
    aiProvider: json['aiProvider'] ?? 'gemini',
    aiModel: json['aiModel'] ?? 'gemini-2.0-flash',
    emergencyContacts: (json['emergencyContacts'] as List? ?? [])
        .map((e) => EmergencyContact.fromJson(e)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'notifications': notifications, 'sound': sound, 'haptic': haptic,
    'aiProvider': aiProvider, 'aiModel': aiModel,
    'emergencyContacts': emergencyContacts.map((e) => e.toJson()).toList(),
  };

  UserSettings copyWith({
    bool? notifications, bool? sound, bool? haptic,
    String? aiProvider, String? aiModel, List<EmergencyContact>? emergencyContacts,
  }) => UserSettings(
    notifications: notifications ?? this.notifications,
    sound: sound ?? this.sound,
    haptic: haptic ?? this.haptic,
    aiProvider: aiProvider ?? this.aiProvider,
    aiModel: aiModel ?? this.aiModel,
    emergencyContacts: emergencyContacts ?? this.emergencyContacts,
  );
}

class EmergencyContact {
  final String name;
  final String phone;
  EmergencyContact({required this.name, required this.phone});
  factory EmergencyContact.fromJson(Map<String, dynamic> j) =>
      EmergencyContact(name: j['name'] ?? '', phone: j['phone'] ?? '');
  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};
}

class WatchInfo {
  final String? connectionType;
  final String? macAddress;
  final String? token;
  final bool isConnected;

  WatchInfo({this.connectionType, this.macAddress, this.token, this.isConnected = false});

  factory WatchInfo.fromJson(Map<String, dynamic> json) => WatchInfo(
    connectionType: json['connectionType'],
    macAddress: json['macAddress'],
    token: json['token'],
    isConnected: json['isConnected'] ?? false,
  );
}

class HealthReading {
  final double heartRate;
  final double systolic;
  final double diastolic;
  final int steps;
  final double? lat;
  final double? lng;
  final DateTime timestamp;

  HealthReading({
    this.heartRate = 0, this.systolic = 0, this.diastolic = 0,
    this.steps = 0, this.lat, this.lng, DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  static final empty = HealthReading();

  factory HealthReading.fromJson(Map<String, dynamic> json) => HealthReading(
    heartRate: (json['heartRate'] ?? json['bpm'] ?? 0).toDouble(),
    systolic: (json['systolic'] ?? json['sys'] ?? 0).toDouble(),
    diastolic: (json['diastolic'] ?? json['dia'] ?? 0).toDouble(),
    steps: json['steps'] ?? 0,
    lat: json['coordinates']?['lat']?.toDouble(),
    lng: json['coordinates']?['lng']?.toDouble(),
    timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'heartRate': heartRate,
    'systolic': systolic,
    'diastolic': diastolic,
    'steps': steps,
    'coordinates': {'lat': lat, 'lng': lng},
    'timestamp': timestamp.toIso8601String(),
  };
}

class ChatMessage {
  final String role; // 'user' | 'ai'
  final String content;
  final DateTime timestamp;

  ChatMessage({required this.role, required this.content, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: json['role'] ?? 'user',
    content: json['content'] ?? '',
    timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
  );

  bool get isUser => role == 'user';
}
