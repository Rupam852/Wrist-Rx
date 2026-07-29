import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/storage_service.dart';
import '../../shared/models/models.dart';
import 'package:firebase_auth/firebase_auth.dart';

final aiMessagesProvider = StateNotifierProvider<AiMessagesNotifier, List<ChatMessage>>((ref) {
  return AiMessagesNotifier();
});

final aiLoadingProvider = StateProvider<bool>((ref) => false);

class AiMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  AiMessagesNotifier() : super([]);

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
      final result = await _api.post(ApiConstants.aiChat, {
        'message': message,
        'apiKey': apiKey,
        'model': aiModel,
      });
      final aiResponse = result['response'] as String;
      state = [...state, ChatMessage(role: 'ai', content: aiResponse)];
    } catch (e) {
      state = [...state,
        ChatMessage(role: 'ai', content: 'Sorry, I encountered an error. Please try again.')
      ];
    }
  }

  void clear() => state = [];
}
