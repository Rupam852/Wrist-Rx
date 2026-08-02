import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/top_toast_service.dart';
import '../../shared/models/models.dart';
import '../watch/watch_provider.dart';
import 'reminder_provider.dart';
import 'add_reminder_sheet.dart';

class MedicineReminderScreen extends ConsumerWidget {
  const MedicineReminderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state          = ref.watch(reminderProvider);
    final watchConnected = ref.watch(watchConnectedProvider);
    final notifier       = ref.read(reminderProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        title: const Text(
          'Medicine Reminder',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _Body(
              state:          state,
              watchConnected: watchConnected,
              notifier:       notifier,
            ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  final ReminderState state;
  final bool          watchConnected;
  final ReminderNotifier notifier;

  const _Body({
    required this.state,
    required this.watchConnected,
    required this.notifier,
  });

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _hasChanges = false;

  void _markChanged() => setState(() => _hasChanges = true);

  // ── Add Reminder ────────────────────────────────────────────────
  Future<void> _openAddSheet() async {
    HapticFeedback.selectionClick();
    final result = await showModalBottomSheet<MedicineReminder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddReminderSheet(),
    );
    if (result != null) {
      widget.notifier.addReminder(result);
      _markChanged();
    }
  }

  // ── Remove Reminder ─────────────────────────────────────────────
  void _removeReminder(String reminderId, String name) {
    HapticFeedback.mediumImpact();
    widget.notifier.removeReminder(reminderId);
    _markChanged();

    // Show undo snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name removed'),
        backgroundColor: AppColors.cardDark,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Save Changes ────────────────────────────────────────────────
  Future<void> _saveChanges() async {
    HapticFeedback.mediumImpact();
    final success = await widget.notifier.saveChanges();
    if (mounted) {
      if (success) {
        setState(() => _hasChanges = false);
        TopToast.show(
          context,
          title: 'Saved!',
          message: 'Medicine reminders updated successfully.',
          type: TopToastType.success,
        );
      } else {
        TopToast.show(
          context,
          title: 'Save Failed',
          message: 'Could not save reminders. Check connection.',
          type: TopToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s              = ref.watch(reminderProvider);
    final watchConnected = ref.watch(watchConnectedProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── Watch Alert Toggle Card ──────────────────────────────
        _WatchAlertCard(
          enabled:        s.watchAlertEnabled,
          watchConnected: watchConnected,
          onChanged: (value) {
            HapticFeedback.selectionClick();
            widget.notifier.setWatchAlertEnabled(value);
            _markChanged();
          },
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05),

        const SizedBox(height: 20),

        // ── Reminders List ───────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Reminders',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              '${s.reminders.length} set',
              style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (s.reminders.isEmpty)
          _EmptyState()
        else
          ...s.reminders.asMap().entries.map((entry) {
            final idx      = entry.key;
            final reminder = entry.value;
            return _ReminderCard(
              reminder:   reminder,
              onRemove:   () => _removeReminder(reminder.reminderId, reminder.name),
            )
                .animate(delay: (idx * 60).ms)
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.05);
          }),

        const SizedBox(height: 16),

        // ── Add Button ───────────────────────────────────────────
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _openAddSheet,
          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          label: const Text('Add Reminder', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ).animate().fadeIn(delay: 200.ms),

        const SizedBox(height: 12),

        // ── Save Changes ─────────────────────────────────────────
        AnimatedOpacity(
          opacity:  _hasChanges ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _hasChanges ? AppColors.primary : Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _hasChanges ? _saveChanges : null,
            icon: s.isSaving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, size: 20),
            label: Text(
              s.isSaving ? 'Saving…' : 'Save Changes',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ).animate().fadeIn(delay: 250.ms),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Watch Alert Toggle Card ──────────────────────────────────────────────────

class _WatchAlertCard extends StatelessWidget {
  final bool enabled;
  final bool watchConnected;
  final ValueChanged<bool> onChanged;

  const _WatchAlertCard({
    required this.enabled,
    required this.watchConnected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = watchConnected; // toggle is only interactive when watch is connected

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled && watchConnected
              ? AppColors.primary.withOpacity(0.4)
              : Colors.white.withOpacity(0.07),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (enabled && watchConnected)
                      ? AppColors.primary.withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.watch_rounded,
                  color: (enabled && watchConnected) ? AppColors.primary : Colors.white38,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Watch Alert',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      watchConnected
                          ? 'Watch connected — alerts active when ON'
                          : 'Connect your watch to enable alerts',
                      style: TextStyle(
                        color: watchConnected ? Colors.white54 : Colors.orange.shade300,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Toggle — grayed out when watch not connected
              Switch(
                value:            isActive ? enabled : false,
                onChanged:        isActive ? onChanged : null,
                activeColor:      AppColors.primary,
                inactiveThumbColor: Colors.white30,
                inactiveTrackColor: Colors.white12,
              ),
            ],
          ),

          // Status chip
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: watchConnected && enabled
                  ? Colors.green.withOpacity(0.12)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  watchConnected && enabled ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 10,
                  color: watchConnected && enabled ? Colors.green : Colors.white30,
                ),
                const SizedBox(width: 6),
                Text(
                  watchConnected
                      ? (enabled ? 'Alerts ON — watch will vibrate at reminder time' : 'Alerts OFF')
                      : 'Watch not connected',
                  style: TextStyle(
                    color: watchConnected && enabled ? Colors.green : Colors.white30,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reminder Card ────────────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  final MedicineReminder reminder;
  final VoidCallback      onRemove;

  const _ReminderCard({required this.reminder, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          // Time badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reminder.timeLabel12h,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (reminder.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    reminder.description,
                    style: TextStyle(color: AppColors.onSurfaceDark, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Remove button
          IconButton(
            icon: const Icon(Icons.cancel_rounded, color: Colors.white24, size: 22),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.medication_outlined, color: Colors.white.withOpacity(0.2), size: 40),
          const SizedBox(height: 12),
          Text(
            'No reminders yet',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Add Reminder" to set your first medicine reminder.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
