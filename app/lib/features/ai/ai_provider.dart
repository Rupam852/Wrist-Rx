import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/storage_service.dart';
import '../../shared/models/models.dart';
import '../home/health_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

final aiMessagesProvider = StateNotifierProvider<AiMessagesNotifier, List<ChatMessage>>((ref) {
  return AiMessagesNotifier(ref);
});

final aiLoadingProvider = StateProvider<bool>((ref) => false);

class AiMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  AiMessagesNotifier(this._ref) : super([]);

  final _api = ApiService();

  Future<void> loadHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final result = await _api.get(ApiConstants.aiConversation(uid));
      final msgs = (result['messages'] as List? ?? [])
          .map((m) => ChatMessage.fromJson(m)).toList();
      state = msgs;
    } catch (_) {}
  }

  Future<void> sendMessage(String message, String aiModel) async {
    final apiKey = await StorageService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      state = [...state,
        ChatMessage(role: 'user', content: message),
        ChatMessage(role: 'ai', content: '⚠️ Please add your Gemini API key in Settings → AI Configuration to use the AI assistant.'),
      ];
      return;
    }

    // Add user message immediately
    state = [...state, ChatMessage(role: 'user', content: message)];

    try {
      final health = _ref.read(healthProvider);
      final result = await _api.post(ApiConstants.aiChat, {
        'message': message,
        'apiKey': apiKey,
        'model': aiModel,
        'healthData': {
          'heartRate': health.heartRate,
          'systolic': health.systolic,
          'diastolic': health.diastolic,
          'steps': health.steps,
          'lat': health.lat,
          'lng': health.lng,
        },
      });

      if (result['success'] == true && result['response'] != null) {
        state = [...state, ChatMessage(role: 'ai', content: result['response'] as String)];
      } else {
        final errMsg = result['message'] ?? 'Unknown backend response error';
        state = [...state, ChatMessage(role: 'ai', content: '⚠️ Service Error: $errMsg')];
      }
    } catch (e) {
      state = [...state,
        ChatMessage(role: 'ai', content: '⚠️ Connection Error: Unable to connect to Wrist Rx server. Please check your internet connection.')
      ];
    }
  }

  void clear() => state = [];
}
