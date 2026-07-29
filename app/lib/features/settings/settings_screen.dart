import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../../shared/models/models.dart';
import '../auth/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _apiKeyObscured = true;
  bool _isSavingKey = false;
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
      case 'notifications': newSettings = user.settings.copyWith(notifications: value); break;
      case 'sound': newSettings = user.settings.copyWith(sound: value); break;
      case 'haptic': newSettings = user.settings.copyWith(haptic: value); break;
      default: return;
    }
    await ref.read(userModelProvider.notifier).updateSettings(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userModelProvider);
    final settings = user?.settings ?? UserSettings();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Notifications ──────────────────────────────
          _SectionHeader('🔔 Notifications'),
          _SettingsTile(
            title: 'Enable Notifications',
            subtitle: 'Health alerts and reminders',
            value: settings.notifications,
            onChanged: (v) => _updateToggle('notifications', v),
          ),
          const SizedBox(height: 24),

          // ── Sound & Haptic ─────────────────────────────
          _SectionHeader('🔊 Sound & Haptic'),
          _SettingsTile(
            title: 'Sound',
            subtitle: 'Alert sounds for notifications',
            value: settings.sound,
            onChanged: (v) => _updateToggle('sound', v),
          ),
          _SettingsTile(
            title: 'Haptic Feedback',
            subtitle: 'Vibration feedback in app',
            value: settings.haptic,
            onChanged: (v) => _updateToggle('haptic', v),
          ),
          const SizedBox(height: 24),

          // ── AI Configuration ───────────────────────────
          _SectionHeader('🤖 AI Configuration'),
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
                // Provider
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Provider', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text('Google Gemini', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                  ]),
                ]),
                const Divider(height: 24),

                // Model selector
                const Text('Model', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 10),
                ..._models.map((m) => GestureDetector(
                  onTap: () => setState(() => _selectedModel = m.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
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
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _isSavingKey ? null : _saveApiKey,
                    icon: _isSavingKey
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_isSavingKey ? 'Saving...' : 'Save API Key'),
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
