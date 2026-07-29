class ApiConstants {
  static const String baseUrl = 'https://wrist-rx.onrender.com';
  static const String wsUrl = 'wss://wrist-rx.onrender.com/ws';

  // Auth
  static const String register = '/api/auth/register';
  static String getUser(String uid) => '/api/auth/user/$uid';
  static String updateUser(String uid) => '/api/auth/user/$uid';
  static String saveOnboarding(String uid) => '/api/auth/user/$uid/onboarding';

  // Health
  static const String saveReading = '/api/health/reading';
  static String todayData(String uid) => '/api/health/$uid/today';
  static String historyData(String uid) => '/api/health/$uid/history';

  // Watch
  static const String connectBluetooth = '/api/watch/connect-bluetooth';
  static const String connectToken = '/api/watch/connect-token';
  static String watchStatus(String uid) => '/api/watch/$uid/status';
  static String disconnectWatch(String uid) => '/api/watch/$uid/disconnect';

  // AI
  static const String aiChat = '/api/ai/chat';
  static String aiConversation(String uid) => '/api/ai/conversation/$uid';
  static const String aiOnboardingComplete = '/api/ai/onboarding/complete';

  // SOS
  static const String sosTrigger = '/api/sos/trigger';
  static String sosHistory(String uid) => '/api/sos/$uid/history';
}
