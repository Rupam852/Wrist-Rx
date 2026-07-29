import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../home/health_provider.dart';
import 'watch_provider.dart';

class WatchConnectSheet extends ConsumerStatefulWidget {
  const WatchConnectSheet({super.key});

  @override
  ConsumerState<WatchConnectSheet> createState() => _WatchConnectSheetState();
}

class _WatchConnectSheetState extends ConsumerState<WatchConnectSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tokenController = TextEditingController();
  bool _isTokenLoading = false;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tokenController.dispose();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startBleScan() async {
    setState(() { _isScanning = true; _scanResults = []; });
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      FlutterBluePlus.scanResults.listen((results) {
        if (mounted) setState(() => _scanResults = results.where((r) => r.device.platformName.isNotEmpty).toList());
      });
      await Future.delayed(const Duration(seconds: 10));
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;
    setState(() => _isTokenLoading = true);
    final success = await ref.read(watchProvider.notifier).connectViaToken(token);
    if (mounted) {
      setState(() => _isTokenLoading = false);
      if (success) {
        ref.read(watchConnectedProvider.notifier).state = true;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Watch connected via Token!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Invalid token. Please check and try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.watch_rounded, color: Colors.white, size: 24)),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Connect Watch', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('Choose connection method', style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 13)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.onSurfaceDark,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(text: '📶 Bluetooth'),
                Tab(text: '🌐 Token'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _BluetoothTab(
                  scanResults: _scanResults,
                  isScanning: _isScanning,
                  onScan: _startBleScan,
                  onConnect: (device) async {
                    await ref.read(watchProvider.notifier).connectViaBluetooth(device);
                    ref.read(watchConnectedProvider.notifier).state = true;
                    if (mounted) Navigator.pop(context);
                  },
                ),
                _TokenTab(
                  controller: _tokenController,
                  isLoading: _isTokenLoading,
                  onConnect: _connectToken,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BluetoothTab extends StatelessWidget {
  final List<ScanResult> scanResults;
  final bool isScanning;
  final VoidCallback onScan;
  final Function(BluetoothDevice) onConnect;

  const _BluetoothTab({
    required this.scanResults, required this.isScanning,
    required this.onScan, required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (isScanning)
            Column(children: [
              const SizedBox(height: 20),
              SizedBox(width: 60, height: 60,
                child: Stack(alignment: Alignment.center, children: [
                  ...List.generate(3, (i) => Container(
                    width: 20.0 + i * 20,
                    height: 20.0 + i * 20,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary.withOpacity(0.4 - i * 0.1), width: 2),
                      shape: BoxShape.circle,
                    ),
                  ).animate(onPlay: (c) => c.repeat())
                    .scale(begin: const Offset(0.8, 0.8), delay: Duration(milliseconds: i * 200), duration: 1.seconds)
                    .fadeOut(duration: 1.seconds)),
                  const Icon(Icons.bluetooth_searching_rounded, color: AppColors.primary, size: 24),
                ])),
              const SizedBox(height: 12),
              const Text('Scanning for devices...', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
            ]),
          if (scanResults.isEmpty && !isScanning)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.bluetooth_disabled_rounded, color: AppColors.onSurfaceDark, size: 64),
                const SizedBox(height: 16),
                Text('No devices found', style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 16)),
                const SizedBox(height: 8),
                Text('Make sure your watch is nearby\nand Bluetooth is enabled',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.onSurfaceDark.withOpacity(0.7), fontSize: 13)),
              ]),
            ),
          ...scanResults.map((r) => ListTile(
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.watch_rounded, color: AppColors.primary),
            ),
            title: Text(r.device.platformName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            subtitle: Text(r.device.remoteId.str, style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 12)),
            trailing: FilledButton(
              onPressed: () => onConnect(r.device),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              child: const Text('Connect', style: TextStyle(fontSize: 13)),
            ),
          )),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: isScanning ? null : onScan,
              icon: isScanning
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.bluetooth_searching_rounded),
              label: Text(isScanning ? 'Scanning...' : 'Scan for Devices'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenTab extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onConnect;

  const _TokenTab({required this.controller, required this.isLoading, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Find the unique token on your watch settings screen.',
                style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 13, height: 1.4))),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('Watch Token', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'XXXX-XXXX-XXXX',
              prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.primary),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear_rounded, color: Colors.white30),
                onPressed: () => controller.clear(),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: isLoading ? null : onConnect,
              icon: isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.link_rounded),
              label: Text(isLoading ? 'Connecting...' : 'Connect Watch'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
