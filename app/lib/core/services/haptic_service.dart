import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/auth_provider.dart';

/// 📳 Premium Cross-Device Haptic Feedback Service
/// Provides rich, tactile, optimized haptic vibrations across all Android & iOS devices.
class HapticService {
  /// Checks if user has enabled Haptic Feedback in Settings (defaults to true)
  static bool _isEnabled(WidgetRef? ref) {
    if (ref == null) return true;
    try {
      final user = ref.read(userModelProvider);
      return user?.settings.haptic ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Subtle crisp tick for card taps, navigation tabs, and icon taps
  static Future<void> lightImpact([WidgetRef? ref]) async {
    if (!_isEnabled(ref)) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      try {
        await HapticFeedback.selectionClick();
      } catch (_) {}
    }
  }

  /// Satisfying tactile bump for primary button presses, modal sheet triggers
  static Future<void> mediumImpact([WidgetRef? ref]) async {
    if (!_isEnabled(ref)) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      try {
        await HapticFeedback.vibrate();
      } catch (_) {}
    }
  }

  /// Strong firm feedback for important action confirmations
  static Future<void> heavyImpact([WidgetRef? ref]) async {
    if (!_isEnabled(ref)) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      try {
        await HapticFeedback.vibrate();
      } catch (_) {}
    }
  }

  /// Crisp selection tick for radio buttons, switches, and setting toggles
  static Future<void> selectionClick([WidgetRef? ref]) async {
    if (!_isEnabled(ref)) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  /// Rhythmic countdown ticks during SOS countdown (3... 2... 1...)
  static Future<void> sosCountdownTick([WidgetRef? ref]) async {
    if (!_isEnabled(ref)) return;
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Heavy double impact + continuous vibration pattern when SOS is dispatched
  static Future<void> sosEmergencyVibrate([WidgetRef? ref]) async {
    if (!_isEnabled(ref)) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Crisp double tick for success toast notifications
  static Future<void> success([WidgetRef? ref]) async {
    if (!_isEnabled(ref)) return;
    try {
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 60));
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Triple pulse for warning/error toasts
  static Future<void> error([WidgetRef? ref]) async {
    if (!_isEnabled(ref)) return;
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 70));
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}
