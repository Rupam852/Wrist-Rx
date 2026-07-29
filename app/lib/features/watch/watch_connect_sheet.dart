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

  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  bool _isTokenLoading = false;
  String? _connectingDeviceId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _startBleScan();
  }

  Future<void> _startBleScan() async {
    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
      FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            _scanResults = results.where((r) => r.device.platformName.isNotEmpty).toList();
          });
        }
      });
    } catch (_) {}

    await Future.delayed(const Duration(seconds: 8));
    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _connectBluetoothDevice(BluetoothDevice device) async {
    setState(() => _connectingDeviceId = device.remoteId.str);
    try {
      await ref.read(watchProvider.notifier).connectViaBluetooth(device);
      ref.read(watchConnectedProvider.notifier).state = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.bluetooth_connected_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text('Connected to ${device.platformName}!'),
            ]),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _connectingDeviceId = null);
    }
  }

  Future<void> _connectToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    setState(() => _isTokenLoading = true);
    final success = await ref.read(watchProvider.notifier).connectViaToken(token);
    setState(() => _isTokenLoading = false);

    if (success && mounted) {
      ref.read(watchConnectedProvider.notifier).state = true;
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),

          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceDark,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            tabs: const [
              Tab(icon: Icon(Icons.bluetooth_rounded, size: 20), text: 'Bluetooth'),
              Tab(icon: Icon(Icons.vpn_key_rounded, size: 20), text: 'Watch Token'),
            ],
          ),

          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _BluetoothTab(
                  scanResults: _scanResults,
                  isScanning: _isScanning,
                  connectingDeviceId: _connectingDeviceId,
                  onScan: _startBleScan,
                  onConnect: _connectBluetoothDevice,
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
  final String? connectingDeviceId;
  final VoidCallback onScan;
  final Function(BluetoothDevice) onConnect;

  const _BluetoothTab({
    required this.scanResults, required this.isScanning,
    required this.connectingDeviceId,
    required this.onScan, required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          if (isScanning)
            Column(children: [
              const SizedBox(height: 16),
              SizedBox(width: 60, height: 60,
                child: Stack(alignment: Alignment.center, children: [
                  ...List.generate(3, (i) => Container(
                    width: 20.0 + i * 20,
                    height: 20.0 + i * 20,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4 - i * 0.1), width: 2),
                      shape: BoxShape.circle,
                    ),
                  ).animate(onPlay: (c) => c.repeat())
                    .scale(begin: const Offset(0.8, 0.8), delay: Duration(milliseconds: i * 200), duration: 1.seconds)
                    .fadeOut(duration: 1.seconds)),
                  const Icon(Icons.bluetooth_searching_rounded, color: AppColors.primary, size: 24),
                ])),
              const SizedBox(height: 10),
              const Text('Scanning for devices...', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
            ]),
          // Device list - scrollable
          Expanded(
            child: scanResults.isEmpty && !isScanning
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.bluetooth_disabled_rounded, color: AppColors.onSurfaceDark, size: 64),
                    const SizedBox(height: 16),
                    Text('No devices found', style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Make sure your watch is nearby\nand Bluetooth is enabled',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.onSurfaceDark.withValues(alpha: 0.7), fontSize: 13)),
                  ])
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: scanResults.length,
                    itemBuilder: (context, index) {
                      final r = scanResults[index];
                      final isConnectingThis = connectingDeviceId == r.device.remoteId.str;
                      final isConnectingAny = connectingDeviceId != null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isConnectingThis ? AppColors.primary : Colors.white.withValues(alpha: 0.07),
                            width: isConnectingThis ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.watch_rounded, color: AppColors.primary),
                          ),
                          title: Text(r.device.platformName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            isConnectingThis ? 'Connecting via Bluetooth...' : r.device.remoteId.str,
                            style: TextStyle(
                              color: isConnectingThis ? AppColors.primary : AppColors.onSurfaceDark,
                              fontSize: 12,
                              fontWeight: isConnectingThis ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          trailing: FilledButton(
                            onPressed: isConnectingAny ? null : () => onConnect(r.device),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              backgroundColor: isConnectingThis ? AppColors.primaryContainer : null,
                            ),
                            child: isConnectingThis
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                                      SizedBox(width: 8),
                                      Text('Connecting...', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                                    ],
                                  )
                                : const Text('Connect', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: (isScanning || connectingDeviceId != null) ? null : onScan,
              icon: isScanning
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.bluetooth_searching_rounded),
              label: Text(isScanning ? 'Scanning...' : 'Scan for Devices'),
            ),
          ),
          const SizedBox(height: 4),
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
            style: const TextStyle(color: Colors.white, letterSpacing: 2, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'e.g. WX-8849-2A',
              hintStyle: TextStyle(letterSpacing: 1),
              prefixIcon: Icon(Icons.vpn_key_rounded, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: isLoading ? null : onConnect,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Connect via Token', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
