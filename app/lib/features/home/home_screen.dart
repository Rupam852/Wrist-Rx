import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/top_toast_service.dart';
import '../../core/constants/api_constants.dart';
import '../watch/watch_connect_sheet.dart';
import '../watch/watch_provider.dart';
import '../auth/auth_provider.dart';
import 'health_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _initGpsLocation();
  }

  Future<void> _initGpsLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        return;
      }

      // Step 1: Show LAST KNOWN position instantly (no waiting for GPS satellite lock)
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        ref.read(healthProvider.notifier).updateFromWatch({
          'coordinates': {'lat': lastPos.latitude, 'lng': lastPos.longitude}
        });
      }

      // Step 2: Get FRESH accurate GPS in background and update
      final freshPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        ref.read(healthProvider.notifier).updateFromWatch({
          'coordinates': {'lat': freshPos.latitude, 'lng': freshPos.longitude}
        });
      }
    } catch (_) {}
  }

  /// Called on pull-to-refresh — gets fresh GPS with 5s timeout so spinner doesn't hang
  Future<void> _refreshGpsLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        if (mounted) {
          ref.read(healthProvider.notifier).updateFromWatch({
            'coordinates': {'lat': pos.latitude, 'lng': pos.longitude}
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(healthProvider);
    final isConnected = ref.watch(watchConnectedProvider);
    final isHrSupported = ref.watch(hrSupportedProvider);
    final isBpSupported = ref.watch(bpSupportedProvider);
    final isStepsSupported = ref.watch(stepsSupportedProvider);
    final user = ref.watch(userModelProvider);

    // Listen for out-of-range watch disconnections to trigger top toast + alert dialog
    ref.listen<String?>(watchOutOfRangeProvider, (previous, deviceName) {
      if (deviceName != null) {
        TopToast.show(
          context,
          title: 'Watch Out of Range',
          message: '$deviceName disconnected because it moved out of range.',
          type: TopToastType.warning,
          duration: const Duration(seconds: 5),
        );

        _showOutOfRangeDisconnectDialog(context, deviceName);

        Future.microtask(() => ref.read(watchOutOfRangeProvider.notifier).state = null);
      }
    });

    // Displays stored calculated data immediately, and updates live when watch calculates new data
    final hasHr = health.heartRate > 0;
    final hasBp = health.systolic > 0 && health.diastolic > 0;
    final hasGps = health.lat != null && health.lng != null;


    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Wrist Rx', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
            if (isConnected)
              GestureDetector(
                onTap: () => _confirmDisconnectWatch(context, ref),
                child: Row(
                  children: [
                    Container(width: 6, height: 6,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text('Watch Connected (Tap to Disconnect)', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
                  ],
                ),
              )
            else
              const Text('Watch not connected', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceDark)),
          ],
        ),
        actions: [
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          // Profile avatar
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Padding(
              padding: const EdgeInsets.only(right: 16, left: 4),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryContainer,
                backgroundImage: user?.photoUrl.isNotEmpty == true
                    ? NetworkImage(user!.photoUrl) : null,
                child: user?.photoUrl.isEmpty != false
                    ? const Icon(Icons.person_rounded, color: Colors.white, size: 20)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.cardDark,
        onRefresh: () async {
          // Refresh GPS location + backend data in parallel
          await Future.wait([
            _refreshGpsLocation(),
            ref.read(healthProvider.notifier).fetchLatestDataFromBackend(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          child: Column(
            children: [
              // Connect or Connected Watch Banner
              if (!isConnected)
                _ConnectWatchBanner().animate().fadeIn().slideY(begin: -0.2)
              else
                _ConnectedWatchBanner(
                  onDisconnect: () => _confirmDisconnectWatch(context, ref),
                ).animate().fadeIn().slideY(begin: -0.2),

              const SizedBox(height: 12),

              // Metric Cards Grid (5 Health Cards with hardware capability checks)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.9,
                children: [
                  // 1. Heart Rate
                  _MetricCard(
                    gradient: AppColors.heartGradient,
                    icon: Icons.favorite_rounded,
                    title: 'Heart Rate',
                    value: (isConnected && !isHrSupported)
                        ? 'N/A'
                        : (hasHr ? health.heartRate.round().toString() : '--'),
                    unit: (isConnected && !isHrSupported) ? 'Not supported on watch' : 'BPM',
                    isPulsing: isConnected && hasHr && isHrSupported,
                    pulseController: _pulseController,
                    smallValue: isConnected && !isHrSupported,
                  ),
                  // 2. Blood Pressure
                  _MetricCard(
                    gradient: AppColors.bpGradient,
                    icon: Icons.bloodtype_rounded,
                    title: 'Blood Pressure',
                    value: (isConnected && !isBpSupported)
                        ? 'N/A'
                        : (hasBp ? '${health.systolic.round()}/${health.diastolic.round()}' : '--/--'),
                    unit: (isConnected && !isBpSupported) ? 'Not supported on watch' : 'mmHg',
                    isPulsing: isConnected && hasBp && isBpSupported,
                    pulseController: _pulseController,
                    smallValue: isConnected && !isBpSupported,
                  ),
                  // 3. Steps Pedometer
                  _MetricCard(
                    gradient: AppColors.stepsGradient,
                    icon: Icons.directions_walk_rounded,
                    title: 'Steps Pedometer',
                    value: (isConnected && !isStepsSupported)
                        ? 'N/A'
                        : _formatSteps(health.steps),
                    unit: (isConnected && !isStepsSupported) ? 'Not supported on watch' : 'steps',
                    isPulsing: isConnected && isStepsSupported,
                    pulseController: _pulseController,
                    smallValue: isConnected && !isStepsSupported,
                  ),
                  // 5. GPS Location (Tap to view/share map link)
                  GestureDetector(
                    onTap: hasGps ? () => showLocationShareDialog(context, health.lat!, health.lng!) : null,
                    child: _MetricCard(
                      gradient: AppColors.gpsGradient,
                      icon: Icons.location_on_rounded,
                      title: 'GPS Location (Tap)',
                      value: hasGps ? health.lat!.toStringAsFixed(3) : '--',
                      unit: hasGps ? 'Tap to share' : 'lat/lng',
                      isPulsing: isConnected && hasGps,
                      pulseController: _pulseController,
                      smallValue: true,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 20),

              // SOS Button
              _SosButton(),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 10000) return '${(steps / 1000).toStringAsFixed(1)}k';
    return steps.toString();
  }

  static void _confirmDisconnectWatch(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Row(children: [
          Icon(Icons.bluetooth_disabled_rounded, color: Colors.orange),
          SizedBox(width: 10),
          Text('Disconnect Watch?', style: TextStyle(color: Colors.white)),
        ]),
        content: const Text(
          'Are you sure you want to disconnect your smartwatch?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(watchProvider.notifier).disconnect();
              ref.read(watchConnectedProvider.notifier).state = false;
              ref.read(healthProvider.notifier).reset();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🔌 Smartwatch disconnected.')),
                );
              }
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  void _showOutOfRangeDisconnectDialog(BuildContext context, String deviceName) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.bluetooth_searching_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('Device Out of Range', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your smartwatch "$deviceName" was disconnected because it went out of Bluetooth range.',
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please bring your watch closer to your phone and tap Reconnect Device below.',
              style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('Dismiss', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(dlgCtx).pop();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const WatchConnectSheet(),
              );
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reconnect Device', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

void showLocationShareDialog(BuildContext context, double lat, double lng) {
    final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';
    showDialog(
      context: context,
      builder: (popCtx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_on_rounded, color: AppColors.primary, size: 26),
            SizedBox(width: 8),
            Text('GPS Location Share', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Google Maps Location Link:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mapsUrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                    tooltip: 'Copy Link',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: mapsUrl));
                      TopToast.show(
                        context,
                        title: 'Link Copied',
                        message: 'Google Maps link copied to clipboard!',
                        type: TopToastType.success,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Coordinates: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
              style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(popCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(popCtx).pop();
              Share.share('🚨 My Emergency GPS Location: $mapsUrl');
            },
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share Location', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

class _ConnectWatchBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const WatchConnectSheet(),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withOpacity(0.15), AppColors.primaryContainer.withOpacity(0.5)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.watch_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Connect Your Watch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  Text('Tap to connect via Bluetooth or Token', style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ConnectedWatchBanner extends StatelessWidget {
  final VoidCallback onDisconnect;
  const _ConnectedWatchBanner({required this.onDisconnect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.watch_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Smartwatch Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                Text('Receiving real-time health data', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onDisconnect,
            icon: const Icon(Icons.link_off_rounded, size: 16, color: Colors.orange),
            label: const Text('Disconnect', style: TextStyle(color: Colors.orange, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.orange),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final LinearGradient gradient;
  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final bool isPulsing;
  final AnimationController pulseController;
  final bool smallValue;

  const _MetricCard({
    required this.gradient, required this.icon, required this.title,
    required this.value, required this.unit, required this.isPulsing,
    required this.pulseController, this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: pulseController,
                builder: (_, child) => Transform.scale(
                  scale: isPulsing ? 1.0 + (pulseController.value * 0.12) : 1.0,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isPulsing ? [
                        BoxShadow(
                          color: gradient.colors.first.withOpacity(0.4 + pulseController.value * 0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ] : [],
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                ),
              ),
              const Spacer(),
              if (isPulsing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('LIVE', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: smallValue ? 22 : 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(unit, style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 12)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SosButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showSosDialog(context, ref),
      child: Container(
        width: double.infinity,
        height: 72,
        decoration: BoxDecoration(
          gradient: AppColors.sosGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.sosRed.withOpacity(0.35),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emergency_rounded, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Text('SOS Emergency', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat())
        .shimmer(delay: 3.seconds, duration: 1.seconds, color: Colors.white24),
    );
  }

  void _showSosDialog(BuildContext context, WidgetRef ref) {
    int countdown = 3;
    Timer? timer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (!ctx.mounted) {
              t.cancel();
              return;
            }
            if (countdown > 1) {
              setState(() => countdown--);
            } else {
              t.cancel();
              Navigator.of(dialogCtx).pop();
              _triggerSos(context, ref);
            }
          });

          return AlertDialog(
            backgroundColor: AppColors.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.emergency_rounded, color: AppColors.sosRed, size: 28),
              SizedBox(width: 10),
              Text('SOS Alert', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sending Emergency Alert in', style: TextStyle(color: AppColors.onSurfaceDark)),
                const SizedBox(height: 12),
                Text('$countdown', style: const TextStyle(color: AppColors.sosRed, fontSize: 64, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Emergency contacts & location will be notified.', textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 13)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  timer?.cancel();
                  Navigator.of(dialogCtx).pop();
                },
                child: const Text('CANCEL', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _triggerSos(BuildContext context, WidgetRef ref) async {
    // 1. Heavy Haptic Vibration (only if haptic setting is enabled)
    try {
      final user = ref.read(userModelProvider);
      if (user?.settings.haptic ?? true) {
        await HapticFeedback.heavyImpact();
        await HapticFeedback.vibrate();
      }
    } catch (_) {}

    // 2. Fetch live GPS location
    double? lat;
    double? lng;
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {}

    // 3. Post SOS Event to Backend API
    try {
      final api = ApiService();
      await api.post(ApiConstants.sosTrigger, {
        'lat': lat,
        'lng': lng,
        'message': '🚨 EMERGENCY SOS ALERT! I need immediate help!',
      });
    } catch (_) {}

    // 4. Get User Emergency Contacts & Dispatch Alerts
    final user = ref.read(userModelProvider);
    final contacts = user?.settings.emergencyContacts ?? [];
    final contactNames = contacts.map((c) => c.name).join(', ');
    final phoneNumbers = contacts.map((c) => c.phone).where((p) => p.isNotEmpty).toList();

    String locationUrl = '';
    if (lat != null && lng != null) {
      locationUrl = ' https://maps.google.com/?q=$lat,$lng';
    }
    final sosMsg = '🚨 EMERGENCY SOS ALERT! I need immediate help! My Location:$locationUrl';

    bool actionDispatched = false;
    if (phoneNumbers.isNotEmpty) {
      final firstPhone = phoneNumbers.first.replaceAll(RegExp(r'[^\d+]'), '');
      
      // 1. Try SMS Intent (Direct Launch)
      final smsUri = Uri(
        scheme: 'sms',
        path: firstPhone,
        queryParameters: <String, String>{
          'body': sosMsg,
        },
      );

      try {
        actionDispatched = await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        actionDispatched = false;
      }

      // 2. Fallback: WhatsApp URI
      if (!actionDispatched) {
        final waUri = Uri.parse('https://wa.me/$firstPhone?text=${Uri.encodeComponent(sosMsg)}');
        try {
          actionDispatched = await launchUrl(waUri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('SOS Triggered!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🚨 Emergency alert logged & broadcasted.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
              const SizedBox(height: 12),
              if (lat != null && lng != null)
                Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: () => showLocationShareDialog(context, lat!, lng!),
                    child: InkWell(
                      onTap: () => showLocationShareDialog(context, lat!, lng!),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Location: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.share_rounded, color: AppColors.primary, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (contacts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('👥 Contacts: $contactNames',
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 4),
                Text(actionDispatched ? '📱 Opening Messages/WhatsApp app...' : '⚠️ Please manually alert your contacts.',
                    style: TextStyle(color: actionDispatched ? Colors.greenAccent : Colors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
              if (contacts.isEmpty) ...[
                const SizedBox(height: 8),
                const Text('⚠️ Note: No emergency contacts configured yet. Add them in Settings → SOS.',
                    style: TextStyle(color: Colors.amber, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.of(dlgCtx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
