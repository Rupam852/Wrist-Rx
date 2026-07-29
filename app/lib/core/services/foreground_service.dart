import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Manages the Android Foreground Service that keeps the BLE watch connection
/// alive when the app is backgrounded or the screen is off.
class WatchForegroundService {
  static final WatchForegroundService _instance = WatchForegroundService._internal();
  factory WatchForegroundService() => _instance;
  WatchForegroundService._internal();

  /// Initialize foreground task settings (call once at app startup)
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'wrist_rx_ble_channel',
        channelName: 'Wrist Rx Watch Connection',
        channelDescription: 'Keeps your smartwatch connected in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the foreground service when watch connects — shows persistent notification
  Future<void> start({required String watchName}) async {
    try {
      // If already running, just update notification text
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Wrist Rx — Connected',
          notificationText: '${watchName.isEmpty ? "Watch" : watchName} is syncing health data',
        );
        return;
      }

      // Request notification permission first (Android 13+)
      final notifPermission = await FlutterForegroundTask.checkNotificationPermission();
      if (notifPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      await FlutterForegroundTask.startService(
        serviceId: 1001,
        serviceTypes: [ForegroundServiceTypes.connectedDevice],
        notificationTitle: 'Wrist Rx — Connected',
        notificationText: '${watchName.isEmpty ? "Watch" : watchName} is syncing health data',
      );
    } catch (_) {}
  }

  /// Update the notification text
  Future<void> updateNotification({required String watchName, String? dataInfo}) async {
    try {
      if (!(await FlutterForegroundTask.isRunningService)) return;
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Wrist Rx — Connected',
        notificationText: dataInfo != null
            ? '${watchName.isEmpty ? "Watch" : watchName} — $dataInfo'
            : '${watchName.isEmpty ? "Watch" : watchName} is syncing health data',
      );
    } catch (_) {}
  }

  /// Stop the foreground service when watch disconnects
  Future<void> stop() async {
    try {
      if (!(await FlutterForegroundTask.isRunningService)) return;
      await FlutterForegroundTask.stopService();
    } catch (_) {}
  }
}
