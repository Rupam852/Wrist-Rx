import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/top_toast_service.dart';
import '../../core/services/haptic_service.dart';
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
  String _selectedModel = 'auto';
  bool _isLoadingKey = true;
  bool? _syncCloudValue;

  // Only 2 options: Auto (smart fallback) and Custom (user-defined)
  final _models = [
    ('auto', 'Auto (Recommended)'),
    ('custom', 'Custom Model'),
  ];

  final _customModelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKey();
    _loadSyncCloudSetting();
    final user = ref.read(userModelProvider);
    _selectedModel = user?.settings.aiModel ?? 'auto';
  }

  Future<void> _loadSyncCloudSetting() async {
    final val = await StorageService.getSetting<bool>('syncCloud');
    if (val != null && mounted) {
      setState(() {
        _syncCloudValue = val;
      });
    }
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
      final modelToSave = _selectedModel == 'custom'
          ? _customModelController.text.trim()
          : 'auto'; // 'auto' tells backend to pick best model
      final newSettings = user.settings.copyWith(aiModel: modelToSave);
      await ref.read(userModelProvider.notifier).updateSettings(newSettings);
    }
    setState(() => _isSavingKey = false);
    if (mounted) {
      TopToast.show(
        context,
        title: 'API Key Saved!',
        message: 'Gemini AI key stored securely on your device.',
        type: TopToastType.success,
      );
    }
  }

  Future<void> _updateToggle(String key, bool value) async {
    HapticService.selectionClick(ref);

    if (key == 'syncCloud') {
      setState(() {
        _syncCloudValue = value;
      });
      await StorageService.saveSetting('syncCloud', value);
    }

    final user = ref.read(userModelProvider);
    if (user != null) {
      UserSettings newSettings;
      switch (key) {
        case 'haptic':
          newSettings = user.settings.copyWith(haptic: value);
          if (value) HapticService.mediumImpact(ref);
          break;
        case 'syncCloud':
          newSettings = user.settings.copyWith(syncCloud: value);
          break;
        default:
          return;
      }
      await ref.read(userModelProvider.notifier).updateSettings(newSettings);
    }
  }


  void _confirmCleanData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 26),
                SizedBox(width: 8),
                Text('Wipe All Local Data?', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
              onPressed: () => Navigator.pop(ctx),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to clean all your local health metrics, steps, location data, and AI chat history from this device?\n\nThis action cannot be undone and resets the app state like a brand new installation.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
                    TopToast.show(
                      context,
                      title: 'Data Cleaned!',
                      message: 'All local health metrics, steps, & AI chat history wiped successfully.',
                      type: TopToastType.success,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    TopToast.show(
                      context,
                      title: 'Clean Failed',
                      message: 'Error cleaning data: $e',
                      type: TopToastType.error,
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isCleaningData = false);
                }
              },
              child: const Text('Yes, Clean All Data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
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
          _SectionHeader('App Preferences'),
          _SettingsTile(
            title: 'Haptic Feedback',
            subtitle: 'Vibrate phone on SOS & key health alerts',
            value: settings.haptic,
            onChanged: (v) => _updateToggle('haptic', v),
          ),
          _SettingsTile(
            title: 'Sync on Cloud',
            subtitle: 'Backup profile & emergency contacts (Health data remains 100% local on device)',
            value: _syncCloudValue ?? settings.syncCloud,
            onChanged: (v) => _updateToggle('syncCloud', v),
          ),


          const SizedBox(height: 24),

          // ── AI Model Configuration ─────────────────────
          _SectionHeader('Gemini AI Configuration'),
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
                const SizedBox(height: 4),
                Text(
                  'Auto uses the latest Gemini model and falls back automatically if one fails.',
                  style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 11),
                ),
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
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.$2, style: TextStyle(
                            color: _selectedModel == m.$1 ? Colors.white : AppColors.onSurfaceDark,
                            fontSize: 13, fontWeight: FontWeight.w500)),
                          if (m.$1 == 'auto')
                            Text('gemini-2.5-flash → 2.0-flash → fallback',
                              style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 10)),
                          if (m.$1 == 'custom')
                            Text('Enter any Gemini model name manually',
                              style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 10)),
                        ],
                      )),
                      if (m.$1 == 'auto')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Smart', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                    ]),
                  ),
                )),
                if (_selectedModel == 'custom') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customModelController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'e.g. gemini-2.5-pro or gemini-2.0-flash',
                      prefixIcon: Icon(Icons.edit_rounded, color: AppColors.primary),
                      helperText: 'Find model names at aistudio.google.com',
                      helperStyle: TextStyle(color: Colors.white38, fontSize: 11),
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

          // ── SOS Emergency Settings ─────────────────────
          _SectionHeader('SOS Emergency Settings'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sosRed.withOpacity(0.3)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.sosRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emergency_rounded, color: AppColors.sosRed, size: 24),
              ),
              title: const Text('SOS Emergency Configuration',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              subtitle: Text(
                user?.settings.emergencyContacts.isNotEmpty == true
                    ? 'Mode: ${user?.settings.sosMethod == "auto_sms" ? "Automatic SIM SMS" : user?.settings.sosMethod == "whatsapp" ? "WhatsApp Direct" : "Manual SMS App"} • ${user?.settings.emergencyContacts.length} Contact(s)'
                    : 'Configure dispatch mode & add emergency contacts',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              onTap: () => context.push('/sos-settings'),
            ),
          ),
          const SizedBox(height: 24),


          // ── About App ──────────────────────────────────
          _SectionHeader('About App'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
              ),
              title: const Text('About Wrist Rx', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text('App version, developer info & contributors', style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              onTap: () => context.push('/about'),
            ),
          ),
          const SizedBox(height: 24),

          // ── Data & Storage Management ─────────────────
          _SectionHeader('Data & Storage Management'),

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
                  'Clean My Local Data & App State',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Wipes all local health metrics, steps, location, and AI chat history from this device, resetting app state like a fresh install.',
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
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (name.isEmpty || phone.isEmpty) {
                TopToast.show(
                  context,
                  title: 'Validation Error',
                  message: 'Please enter both name and phone number.',
                  type: TopToastType.error,
                );
                return;
              }
              final user = ref.read(userModelProvider);
              if (user == null) return;
              final contacts = [
                ...user.settings.emergencyContacts,
                EmergencyContact(name: name, phone: phone)
              ];
              await ref.read(userModelProvider.notifier).updateSettings(
                user.settings.copyWith(emergencyContacts: contacts));
              if (mounted) {
                Navigator.pop(context);
                TopToast.show(
                  context,
                  title: 'Contact Saved!',
                  message: 'Emergency contact "$name" added successfully.',
                  type: TopToastType.success,
                );
              }
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
