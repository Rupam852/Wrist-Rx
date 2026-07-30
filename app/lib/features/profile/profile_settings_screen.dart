import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../core/theme/app_colors.dart';
import '../../core/services/top_toast_service.dart';
import '../auth/auth_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});
  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  late TextEditingController _nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userModelProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 512);
    if (img == null) return;

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final ref2 = FirebaseStorage.instance.ref().child('profiles/$uid.jpg');
      await ref2.putFile(File(img.path));
      final url = await ref2.getDownloadURL();
      await ref.read(userModelProvider.notifier).updateProfile(photoUrl: url);
      if (mounted) {
        TopToast.show(
          context,
          title: 'Photo Updated',
          message: 'Profile photo updated successfully!',
          type: TopToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        TopToast.show(
          context,
          title: 'Upload Failed',
          message: 'Failed to upload photo: $e',
          type: TopToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    await ref.read(userModelProvider.notifier).updateProfile(name: name);
    setState(() => _isSaving = false);
    if (mounted) {
      TopToast.show(
        context,
        title: 'Name Updated',
        message: 'Profile name updated successfully!',
        type: TopToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userModelProvider);
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('Profile Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Avatar
            GestureDetector(
              onTap: _pickAndUploadPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: AppColors.primaryContainer,
                    backgroundImage: user?.photoUrl.isNotEmpty == true ? NetworkImage(user!.photoUrl) : null,
                    child: user?.photoUrl.isEmpty != false
                        ? const Icon(Icons.person_rounded, color: Colors.white, size: 56)
                        : null,
                  ),
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.backgroundDark, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                  if (_isSaving)
                    Positioned.fill(child: Container(
                      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                      child: const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                    )),
                ],
              ),
            ).animate().fadeIn().scale(),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.g_mobiledata, color: AppColors.primary, size: 18),
                const SizedBox(width: 4),
                const Text('Google Account', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 32),
            // Name field
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            // Email (readonly)
            TextField(
              enabled: false,
              controller: TextEditingController(text: user?.email ?? ''),
              style: const TextStyle(color: Colors.white60),
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined, color: Colors.white30),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveName,
                child: const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(userModelProvider.notifier).signOut();
                if (mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
