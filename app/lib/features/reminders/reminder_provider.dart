import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../shared/models/models.dart';
import '../home/health_provider.dart';
import '../watch/watch_provider.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final reminderProvider = StateNotifierProvider<ReminderNotifier, ReminderState>((ref) {
  return ReminderNotifier(ref);
});

// ─── State ────────────────────────────────────────────────────────────────────

class ReminderState {
  final List<MedicineReminder> reminders;
  final bool watchAlertEnabled; // global toggle — only active when watch is connected
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const ReminderState({
    this.reminders         = const [],
    this.watchAlertEnabled = true,
    this.isLoading         = false,
    this.isSaving          = false,
    this.error,
  });

  ReminderState copyWith({
    List<MedicineReminder>? reminders,
    bool? watchAlertEnabled,
    bool? isLoading,
    bool? isSaving,
    String? error,
  }) =>
      ReminderState(
        reminders:         reminders         ?? this.reminders,
        watchAlertEnabled: watchAlertEnabled ?? this.watchAlertEnabled,
        isLoading:         isLoading         ?? this.isLoading,
        isSaving:          isSaving          ?? this.isSaving,
        error:             error             ?? this.error,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ReminderNotifier extends StateNotifier<ReminderState> {
  final Ref ref;
  final _api = ApiService();

  Timer? _clockTimer;
  /// Tracks which reminderIds already fired this minute to avoid double-firing
  final Set<String> _firedThisMinute = {};
  int _lastMinute = -1;

  ReminderNotifier(this.ref) : super(const ReminderState()) {
    fetchReminders();
    _startClock();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // ── Clock ticker: checks every 30s if a reminder should fire ──────────────
  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkAndFire();
    });
  }

  void _checkAndFire() {
    final watchConnected = ref.read(watchConnectedProvider);
    if (!watchConnected) return;

    final now    = DateTime.now();
    final minute = now.hour * 60 + now.minute;

    // Reset fired-set at the start of a new minute
    if (minute != _lastMinute) {
      _firedThisMinute.clear();
      _lastMinute = minute;
    }

    for (final reminder in state.reminders) {
      final reminderMinute = reminder.timeHour * 60 + reminder.timeMinute;
      if (reminderMinute == minute && !_firedThisMinute.contains(reminder.reminderId)) {
        _firedThisMinute.add(reminder.reminderId);
        _fireReminder(reminder);
      }
    }
  }

  /// Sends BLE notification & status bar alert to watch for this reminder
  void _fireReminder(MedicineReminder reminder) {
    try {
      ref.read(watchProvider.notifier).sendWatchNotification(reminder.name);
    } catch (_) {}
  }

  // ── API calls ─────────────────────────────────────────────────────────────

  Future<void> fetchReminders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _api.get(ApiConstants.remindersGet);
      final items = (result['reminders'] as List? ?? [])
          .map((e) => MedicineReminder.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        reminders:         items,
        watchAlertEnabled: result['watchAlertEnabled'] as bool? ?? false,
        isLoading:         false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> saveChanges() async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      await _api.post(ApiConstants.remindersSave, {
        'watchAlertEnabled': state.watchAlertEnabled,
        'reminders':         state.reminders.map((r) => r.toJson()).toList(),
      });
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  // ── Local mutations (applied to state immediately, saved on "Save Changes") ──

  void addReminder(MedicineReminder reminder) {
    state = state.copyWith(reminders: [...state.reminders, reminder]);
  }

  void removeReminder(String reminderId) {
    state = state.copyWith(
      reminders: state.reminders.where((r) => r.reminderId != reminderId).toList(),
    );
  }

  void setWatchAlertEnabled(bool value) {
    state = state.copyWith(watchAlertEnabled: value);
  }

  /// Called externally (e.g. from widget test) to trigger a clock check
  void triggerCheck() => _checkAndFire();
}
