import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../shared/models/models.dart';
import '../auth/auth_provider.dart';
import '../home/health_provider.dart';
import '../ai/ai_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _apiKeyObscured = true;
  bool _isSavingKey = false;
  bool _isCleaningData = false;
  String _selectedModel = 'gemini-2.0-flash';
  bool _isLoadingKey = true;

  final _models = [
    ('gemini-2.0-flash-lite', 'Gemini Flash Lite Latest'),
    ('gemini-2.5-flash-lite', 'Gemini 2.5 Flash Lite'),
    ('gemini-2.0-flash', 'Gemini Flash Latest'),
    ('gemini-2.5-flash', 'Gemini 2.5 Flash'),
    ('custom', 'Custom Model'),
  ];

  final _customModelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKey();
    final user = ref.read(userModelProvider);
    _selectedModel = user?.settings.aiModel ?? 'gemini-2.0-flash';
  }

  Future<void> _loadKey() async {
    final key = await StorageService.getApiKey();
    if (mounted) {
      setState(() {
        if (key != null) _apiKeyController.text = key;
        _isLoadingKey = false;
      });
    }
  }

  Future<void> _saveApiKey() async {
    setState(() => _isSavingKey = true);
    await StorageService.saveApiKey(_apiKeyController.text.trim());
    // Also save model to backend
    final user = ref.read(userModelProvider);
    if (user != null) {
      final newSettings = user.settings.copyWith(aiModel: _selectedModel == 'custom'
          ? _customModelController.text.trim() : _selectedModel);
      await ref.read(userModelProvider.notifier).updateSettings(newSettings);
    }
    setState(() => _isSavingKey = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ API Key saved securely!')));
  }

  Future<void> _updateToggle(String key, bool value) async {
    final user = ref.read(userModelProvider);
    if (user == null) return;
    UserSettings newSettings;
    switch (key) {
      case 'notifications':
        newSettings = user.settings.copyWith(notifications: value);
        break;
      case 'sound':
        newSettings = user.settings.copyWith(sound: value);
        break;
      case 'haptic':
        newSettings = user.settings.copyWith(haptic: value);
        break;
      case 'syncCloud':
        newSettings = user.settings.copyWith(syncCloud: value);
        break;
      default:
        return;
    }
    await ref.read(userModelProvider.notifier).updateSettings(newSettings);
  }

  void _confirmCleanData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
          SizedBox(width: 10),
          Text('Wipe All Data?', style: TextStyle(color: Colors.white)),
        ]),
        content: const Text(
          'Are you sure you want to clean all your health telemetry data from the database and app?\n\nThis action cannot be undone and resets the app state like a brand new installation.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isCleaningData = true);
              try {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  final api = ApiService();
                  await api.delete(ApiConstants.cleanHealthData(uid));
                }
                ref.read(healthProvider.notifier).reset();
                ref.read(aiMessagesProvider.notifier).clear();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✨ All health data & AI chat history wiped!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error cleaning data: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isCleaningData = false);
              }
            },
            child: const Text('Yes, Clean All Data'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userModelProvider);
    final settings = user?.settings ?? UserSettings();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── App Preferences ────────────────────────────
          _SectionHeader('⚙ App Preferences'),
          _SettingsTile(
            title: 'Push Notifications',
            subtitle: 'Get real-time health alerts & watch sync updates',
            value: settings.notifications,
            onChanged: (v) => _updateToggle('notifications', v),
          ),
          _SettingsTile(
            title: 'Haptic Feedback',
            subtitle: 'Vibrate watch & phone on SOS & key alerts',
            value: settings.haptic,
            onChanged: (v) => _updateToggle('haptic', v),
          ),
          _SettingsTile(
            title: 'Sound Alerts',
            subtitle: 'Play audio chimes during high priority events',
            value: settings.sound,
            onChanged: (v) => _updateToggle('sound', v),
          ),
          _SettingsTile(
            title: 'Sync Data on Cloud',
            subtitle: 'Backup & sync health telemetry to cloud database (OFF by default)',
            value: settings.syncCloud,
            onChanged: (v) => _updateToggle('syncCloud', v),
          ),
          const SizedBox(height: 24),

          // ── AI Model Configuration ─────────────────────
          _SectionHeader('🤖 Gemini AI Configuration'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select AI Model', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 12),
                ..._models.map((m) => GestureDetector(
                  onTap: () => setState(() => _selectedModel = m.$1),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedModel == m.$1 ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedModel == m.$1 ? AppColors.primary : Colors.white12,
                        width: 1.5,
                      ),
                    ),
                    child: Row(children: [
                      Icon(_selectedModel == m.$1 ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: _selectedModel == m.$1 ? AppColors.primary : Colors.white30, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(m.$2, style: TextStyle(
                        color: _selectedModel == m.$1 ? Colors.white : AppColors.onSurfaceDark,
                        fontSize: 13, fontWeight: FontWeight.w500))),
                    ]),
                  ),
                )),
                if (_selectedModel == 'custom') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customModelController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Enter model name (e.g. gemini-pro)',
                      prefixIcon: Icon(Icons.edit_rounded, color: AppColors.primary),
                    ),
                  ),
                ],
                const Divider(height: 24),

                // API Key
                const Text('API Credentials', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                Text('Your API key is stored securely on this device.',
                  style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 12)),
                const SizedBox(height: 10),
                _isLoadingKey
                    ? const LinearProgressIndicator()
                    : TextField(
                        controller: _apiKeyController,
                        obscureText: _apiKeyObscured,
                        style: const TextStyle(color: Colors.white, fontSize: 13, letterSpacing: 1),
                        decoration: InputDecoration(
                          hintText: 'Paste your Gemini API key',
                          prefixIcon: const Icon(Icons.key_rounded, color: AppColors.primary),
                          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              icon: Icon(_apiKeyObscured ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                  color: Colors.white30),
                              onPressed: () => setState(() => _apiKeyObscured = !_apiKeyObscured),
                            ),
                            if (_apiKeyController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, color: Colors.white30),
                                onPressed: () { _apiKeyController.clear(); StorageService.deleteApiKey(); },
                              ),
                          ]),
                        ),
                      ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSavingKey ? null : _saveApiKey,
                    icon: _isSavingKey
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      _isSavingKey ? 'Saving...' : 'Save API Key',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Emergency Contacts ─────────────────────────
          _SectionHeader('🚨 Emergency Contacts (SOS)'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(
              children: [
                ...(user?.settings.emergencyContacts ?? []).asMap().entries.map((e) =>
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.sosRed.withOpacity(0.15),
                      child: Text('${e.key + 1}', style: const TextStyle(color: AppColors.sosRed, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(e.value.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(e.value.phone, style: TextStyle(color: AppColors.onSurfaceDark)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: () {},
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: const Icon(Icons.add_rounded, color: AppColors.primary),
                  ),
                  title: const Text('Add Emergency Contact', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
                  onTap: () => _showAddContactDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Data & Storage Management ─────────────────
          _SectionHeader('🧹 Data & Storage Management'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Clean My Data from Database & App',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Wipes all stored health metrics, steps, readings from database and resets app state like a fresh install.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.redAccent, width: 1.5),
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                    ),
                    onPressed: _isCleaningData ? null : () => _confirmCleanData(context),
                    icon: _isCleaningData
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
                        : const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                    label: Text(
                      _isCleaningData ? 'Wiping Data...' : 'Clean All My Data',
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Add Emergency Contact', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary))),
          const SizedBox(height: 12),
          TextField(controller: phoneCtrl, style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final user = ref.read(userModelProvider);
              if (user == null) return;
              final contacts = [...user.settings.emergencyContacts,
                EmergencyContact(name: nameCtrl.text, phone: phoneCtrl.text)];
              await ref.read(userModelProvider.notifier).updateSettings(
                user.settings.copyWith(emergencyContacts: contacts));
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Colors.white, fontWeight: FontWeight.w700)),
  );
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsTile({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
