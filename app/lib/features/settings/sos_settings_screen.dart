import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/top_toast_service.dart';
import '../../core/services/storage_service.dart';
import '../../shared/models/models.dart';
import '../auth/auth_provider.dart';

class SosSettingsScreen extends ConsumerStatefulWidget {
  const SosSettingsScreen({super.key});

  @override
  ConsumerState<SosSettingsScreen> createState() => _SosSettingsScreenState();
}

class _SosSettingsScreenState extends ConsumerState<SosSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _selectedSosMethod;

  @override
  void initState() {
    super.initState();
    _loadSavedSosMethod();
  }

  Future<void> _loadSavedSosMethod() async {
    final saved = await StorageService.getSetting<String>('sos_method');
    if (saved != null && mounted) {
      setState(() {
        _selectedSosMethod = saved;
      });
    }
  }

  Future<void> _updateSosMethod(String method) async {
    // Update local state instantly on tap so UI radio button highlights immediately
    setState(() {
      _selectedSosMethod = method;
    });

    // Save locally in SharedPreferences
    await StorageService.saveSetting('sos_method', method);

    // Request SMS permission if auto_sms is selected
    if (method == 'auto_sms') {
      try {
        final status = await Permission.sms.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            _showRestrictedPermissionGuide(context);
          }
        }
      } catch (_) {}
    }

    var user = ref.read(userModelProvider);
    if (user != null) {
      final newSettings = user.settings.copyWith(sosMethod: method);
      await ref.read(userModelProvider.notifier).updateSettings(newSettings);
    }

    if (mounted) {
      TopToast.show(
        context,
        title: 'Dispatch Mode Updated',
        message: method == 'auto_sms'
            ? 'Automatic Direct SMS enabled (Sends from your SIM card)'
            : method == 'whatsapp'
                ? 'WhatsApp direct launch mode enabled'
                : 'Interactive SMS App mode enabled',
        type: TopToastType.success,
      );
    }
  }

  void _showRestrictedPermissionGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.amberAccent, size: 24),
            SizedBox(width: 10),
            Text('Android Security Protection', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Android 13/14/15 blocks background SMS permissions for newly installed APKs by default ("Restricted Settings").',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How to unlock in 3 easy steps:', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                  SizedBox(height: 6),
                  Text('1. Tap "Open App Info" button below.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('2. Tap 3 dots (⋮) in top right corner.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('3. Tap "Allow restricted settings".', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dlgCtx);
              openAppSettings();
            },
            icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 16),
            label: const Text('Open App Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }




  void _showAddContactDialog() {
    _nameCtrl.clear();
    _phoneCtrl.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: AppColors.sosRed, size: 24),
            SizedBox(width: 8),
            Text('Add Emergency Contact', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Contact Name (e.g. Papa, Brother)',
                prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number with Country Code',
                hintText: '+919876543210',
                prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sosRed),
            onPressed: () async {
              final name = _nameCtrl.text.trim();
              final phone = _phoneCtrl.text.trim();
              if (name.isEmpty || phone.isEmpty) {
                TopToast.show(
                  context,
                  title: 'Validation Error',
                  message: 'Please enter both name and mobile number.',
                  type: TopToastType.error,
                );
                return;
              }

              final user = ref.read(userModelProvider);
              if (user == null) return;

              final currentContacts = List<EmergencyContact>.from(user.settings.emergencyContacts);
              currentContacts.add(EmergencyContact(name: name, phone: phone));

              await ref.read(userModelProvider.notifier).updateSettings(
                user.settings.copyWith(emergencyContacts: currentContacts),
              );

              if (mounted) {
                Navigator.pop(context);
                TopToast.show(
                  context,
                  title: 'Contact Saved!',
                  message: '$name added to emergency contacts.',
                  type: TopToastType.success,
                );
              }
            },
            child: const Text('Save Contact'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userModelProvider);
    final settings = user?.settings ?? UserSettings();
    final contacts = settings.emergencyContacts;
    final currentMethod = _selectedSosMethod ?? settings.sosMethod;


    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('SOS Emergency Settings', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Status Banner ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: contacts.isNotEmpty
                    ? [Colors.green.shade900.withOpacity(0.4), Colors.green.shade800.withOpacity(0.2)]
                    : [Colors.amber.shade900.withOpacity(0.4), Colors.amber.shade800.withOpacity(0.2)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: contacts.isNotEmpty ? Colors.green.shade500 : Colors.amber.shade500,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  contacts.isNotEmpty ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                  color: contacts.isNotEmpty ? Colors.greenAccent : Colors.amberAccent,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contacts.isNotEmpty ? 'SOS Safety Active & Ready' : 'Action Required: Add SOS Contacts',
                        style: TextStyle(
                          color: contacts.isNotEmpty ? Colors.greenAccent : Colors.amberAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contacts.isNotEmpty
                            ? '${contacts.length} Emergency contact(s) configured. Automatic alerts will send from your phone SIM card.'
                            : 'Please add at least 1 emergency contact number below to enable SOS alerts.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Dispatch Mode Selection ────────────────────────
          _SectionHeader('SOS Dispatch Method'),
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
                const Text('Choose how emergency alerts are sent when you press SOS:',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 14),

                // 1. Phone Default Messaging App (Recommended)
                _DispatchOptionTile(
                  id: 'manual_sms',
                  title: 'Phone Default Messaging App (Recommended)',
                  subtitle: 'Opens your default Messages app with all emergency contacts pre-filled in a group draft. You just tap Send!',
                  badgeText: 'RECOMMENDED',
                  badgeColor: Colors.green,
                  icon: Icons.message_rounded,
                  isSelected: currentMethod == 'manual_sms' || currentMethod == 'auto_sms',
                  onTap: () => _updateSosMethod('manual_sms'),
                ),

                // 2. WhatsApp Direct Launch
                _DispatchOptionTile(
                  id: 'whatsapp',
                  title: 'WhatsApp Direct Launch',
                  subtitle: 'Opens WhatsApp app with pre-filled distress message & live map location link.',
                  badgeText: 'WhatsApp',
                  badgeColor: Colors.teal,
                  icon: Icons.chat_rounded,
                  isSelected: currentMethod == 'whatsapp',
                  onTap: () => _updateSosMethod('whatsapp'),
                ),
              ],
            ),

          ),
          const SizedBox(height: 24),

          // ── Emergency Contacts List ─────────────────────────
          _SectionHeader('Saved Emergency Contacts (${contacts.length})'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(
              children: [
                if (contacts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Icon(Icons.person_off_rounded, color: Colors.white30, size: 40),
                        const SizedBox(height: 8),
                        const Text('No emergency contacts added yet.',
                            style: TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  )
                else
                  ...contacts.asMap().entries.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.sosRed.withOpacity(0.2),
                        child: Text('${e.key + 1}',
                            style: const TextStyle(color: AppColors.sosRed, fontWeight: FontWeight.w700)),
                      ),
                      title: Text(e.value.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text(e.value.phone,
                          style: const TextStyle(color: AppColors.primary, fontSize: 13)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () async {
                          final currentContacts = List<EmergencyContact>.from(contacts);
                          if (e.key < currentContacts.length) {
                            final removedName = currentContacts[e.key].name;
                            currentContacts.removeAt(e.key);
                            await ref.read(userModelProvider.notifier).updateSettings(
                              settings.copyWith(emergencyContacts: currentContacts),
                            );
                            if (context.mounted) {
                              TopToast.show(
                                context,
                                title: 'Contact Removed',
                                message: '$removedName removed from emergency contacts.',
                                type: TopToastType.info,
                              );
                            }
                          }
                        },
                      ),
                    ),
                  )),

                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _showAddContactDialog,
                    icon: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 18),
                    label: const Text('Add Emergency Contact',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Emergency Template Preview ──────────────────────
          _SectionHeader('Emergency Message Format'),

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
                const Text('When SOS is triggered, your contacts receive:',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.sosRed.withOpacity(0.3)),
                  ),
                  child: const Text(
                    '🚨 EMERGENCY SOS ALERT! I need immediate help! My Location: https://maps.google.com/?q=LAT,LNG',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace', height: 1.4),
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

class _DispatchOptionTile extends StatelessWidget {
  final String id;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DispatchOptionTile({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.black12,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white12,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : Colors.white30,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: isSelected ? AppColors.primary : Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
