import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../home/health_provider.dart';
import 'watch_provider.dart';

class WatchDetailsSheet extends ConsumerWidget {
  const WatchDetailsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const WatchDetailsSheet(),
    );
  }

  void _confirmDisconnect(BuildContext context, WidgetRef ref, String watchName) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.bluetooth_disabled_rounded, color: Colors.redAccent, size: 26),
                SizedBox(width: 8),
                Text('Disconnect Watch?', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
              onPressed: () => Navigator.pop(dlgCtx),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to disconnect $watchName?\n\nHealth sync will pause until you connect your watch again.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
                Navigator.pop(dlgCtx); // Close dialog
                Navigator.pop(context); // Close sheet
                await ref.read(watchProvider.notifier).disconnect();
              },
              child: const Text('Disconnect Device', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),

    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchState = ref.watch(watchProvider);
    final battery = ref.watch(watchBatteryProvider);
    final isCharging = ref.watch(watchIsChargingProvider);
    final watchName = (watchState.deviceName != null && watchState.deviceName!.isNotEmpty)
        ? watchState.deviceName!
        : 'Smartwatch';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Smartwatch Management',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Watch Graphic Card / Wallpaper ───────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.25),
                  AppColors.cardDark,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              children: [
                // Watch Icon Graphic
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.watch_rounded, color: AppColors.primary, size: 48),
                ),
                const SizedBox(height: 12),
                Text(
                  watchName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isCharging ? Icons.bolt_rounded : Icons.circle,
                          color: isCharging ? Colors.yellowAccent : Colors.greenAccent, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        isCharging ? 'Charging • Live Syncing' : 'Connected & Live Syncing',
                        style: TextStyle(
                          color: isCharging ? Colors.yellowAccent : Colors.greenAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Real-Time Battery Card ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCharging ? Colors.yellowAccent.withOpacity(0.4) : Colors.white.withOpacity(0.07),
                width: isCharging ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCharging
                              ? Icons.battery_charging_full_rounded
                              : battery >= 80
                                  ? Icons.battery_full_rounded
                                  : battery >= 40
                                      ? Icons.battery_5_bar_rounded
                                      : Icons.battery_2_bar_rounded,
                          color: isCharging
                              ? Colors.yellowAccent
                              : battery >= 20
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isCharging ? 'Watch Battery (Charging)' : 'Watch Battery (Real-Time)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (isCharging) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.yellow.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.bolt_rounded, color: Colors.yellowAccent, size: 12),
                                SizedBox(width: 2),
                                Text('CHARGING',
                                    style: TextStyle(color: Colors.yellowAccent, fontSize: 9, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '$battery%',
                          style: TextStyle(
                            color: isCharging
                                ? Colors.yellowAccent
                                : battery >= 20
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: battery / 100.0,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCharging
                          ? Colors.yellowAccent
                          : battery >= 20
                              ? Colors.greenAccent
                              : Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Connection Telemetry Card ───────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bluetooth_connected_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Background BLE Service',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('Active — Syncing health metrics continuously',
                          style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Disconnect Watch Button ─────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _confirmDisconnect(context, ref, watchName),
              icon: const Icon(Icons.bluetooth_disabled_rounded, color: Colors.redAccent, size: 20),
              label: const Text(
                'Disconnect Watch',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
