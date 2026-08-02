import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/top_toast_service.dart';
import 'watch_protocol_registry.dart';
import 'watch_provider.dart';

class BrandSelectionSheet extends ConsumerWidget {
  const BrandSelectionSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BrandSelectionSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchState = ref.watch(watchProvider);
    final selectedProfile = watchState.selectedBrandProfile;

    final profiles = WatchProtocolRegistry.globalBrandProfiles;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.watch_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Watch Brand Engine',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Locks 100% exact protocol & sensors for your watch',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          ...profiles.map((profile) {
            final isSelected = selectedProfile?.brandName == profile.brandName;
            return _BrandOptionTile(
              profile: profile,
              isSelected: isSelected,
              onTap: () {
                HapticFeedback.mediumImpact();
                ref.read(watchProvider.notifier).selectWatchBrand(profile);
                Navigator.of(context).pop();
                TopToast.show(
                  context,
                  title: '${profile.brandName} Protocol Activated! ⚡',
                  message: 'Dedicated ${profile.brandName} protocol driver locked for live SpO2, Heart Rate, & Reminders.',
                  type: TopToastType.success,
                );
              },
            );
          }),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _BrandOptionTile extends StatelessWidget {
  final WatchBrandProfile profile;
  final bool isSelected;
  final VoidCallback onTap;

  const _BrandOptionTile({
    required this.profile,
    required this.isSelected,
    required this.onTap,
  });

  Color _getBrandColor(String name) {
    if (name.contains('Noise')) return Colors.greenAccent;
    if (name.contains('Fire')) return Colors.deepOrangeAccent;
    if (name.contains('boAt')) return Colors.lightBlueAccent;
    if (name.contains('FitPro')) return Colors.amberAccent;
    return Colors.purpleAccent;
  }

  IconData _getBrandIcon(String name) {
    if (name.contains('Noise')) return Icons.volume_up_rounded;
    if (name.contains('Fire')) return Icons.local_fire_department_rounded;
    if (name.contains('boAt')) return Icons.directions_boat_rounded;
    if (name.contains('FitPro')) return Icons.fitness_center_rounded;
    return Icons.watch_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final brandColor = _getBrandColor(profile.brandName);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? brandColor.withOpacity(0.12) : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? brandColor : Colors.white.withOpacity(0.08),
          width: isSelected ? 1.8 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: brandColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(_getBrandIcon(profile.brandName), color: brandColor, size: 22),
        ),
        title: Text(
          profile.brandName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          profile.namePrefixes.take(5).join(', ').toUpperCase(),
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        trailing: isSelected
            ? Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: brandColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.black, size: 14),
              )
            : const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
      ),
    );
  }
}
