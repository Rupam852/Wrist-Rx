import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/models.dart';
import '../auth/auth_provider.dart';
import 'ai_provider.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiMessagesProvider.notifier).loadHistory();
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    setState(() => _isSending = true);

    final user = ref.read(userModelProvider);
    final model = user?.settings.aiModel ?? 'auto';

    await ref.read(aiMessagesProvider.notifier).sendMessage(text, model);
    setState(() => _isSending = false);

    await Future.delayed(100.ms);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: 300.ms,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiMessagesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Health AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text('Powered by Gemini', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceDark)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == messages.length) {
                        return _TypingIndicator();
                      }
                      return _ChatBubble(message: messages[i])
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.2, end: 0);
                    },
                  ),
          ),
          _InputBar(
            controller: _controller,
            onSend: _send,
            isLoading: _isSending,
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('About Health AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'Your AI assistant uses your health data and profile to provide personalized suggestions.\n\nAdd your Gemini API key in Settings → AI Configuration to enable the AI.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Got it', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser ? AppColors.primaryGradient : null,
                color: isUser ? null : AppColors.cardDark,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                ),
                border: isUser ? null : Border.all(color: Colors.white10),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryContainer,
              child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18),
                bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(children: [
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  ).animate(onPlay: (c) => c.repeat())
                    .fadeOut(delay: Duration(milliseconds: i * 150), duration: 400.ms)
                    .then().fadeIn(duration: 400.ms),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  const _InputBar({required this.controller, required this.onSend, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              maxLines: null,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Ask about your health...',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppColors.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: isLoading ? null : onSend,
            child: AnimatedContainer(
              duration: 200.ms,
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: isLoading ? null : AppColors.primaryGradient,
                color: isLoading ? Colors.white12 : null,
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? const Center(child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30)))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 30)],
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 40),
          ).animate().scale().fadeIn(),
          const SizedBox(height: 20),
          Text('Your Health AI', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Text('Ask me anything about your health!\nI use your data to give personalized advice.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.onSurfaceDark, height: 1.5)),
          const SizedBox(height: 32),
          ...[
            '📊 Analyze my heart rate trend',
            '🚶 How many steps should I take?',
            '💊 Tips for managing my BP',
          ].map((hint) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(hint, style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 13)),
            ),
          )),
        ],
      ),
    );
  }
}
