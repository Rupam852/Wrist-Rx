import 'package:flutter/material.dart';

class AppColors {
  // Primary — Health Green
  static const Color primary = Color(0xFF00C896);
  static const Color primaryContainer = Color(0xFF003828);
  static const Color primaryDark = Color(0xFF00A07A);

  // Secondary
  static const Color secondary = Color(0xFF4C6358);
  static const Color secondaryContainer = Color(0xFF1E3028);

  // SOS / Error
  static const Color error = Color(0xFFFF4757);
  static const Color errorContainer = Color(0xFF4A0010);
  static const Color sosRed = Color(0xFFFF4757);

  // Backgrounds
  static const Color backgroundDark = Color(0xFF0A0F0D);
  static const Color surfaceDark = Color(0xFF111916);
  static const Color cardDark = Color(0xFF1A2420);
  static const Color cardDark2 = Color(0xFF162020);

  // Text
  static const Color onSurfaceDark = Color(0xFFB0C4BC);
  static const Color onPrimary = Colors.white;

  // Metric card colors
  static const Color heartRateColor = Color(0xFFFF6B8A);
  static const Color bpColor = Color(0xFF6B9FFF);
  static const Color spo2Color = Color(0xFF00E5FF);
  static const Color stepsColor = Color(0xFF00C896);
  static const Color gpsColor = Color(0xFFFFB347);

  // AI Chat
  static const Color userBubble = Color(0xFF00C896);
  static const Color aiBubble = Color(0xFF1A2420);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C896), Color(0xFF008060)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D1F18), Color(0xFF0A0F0D)],
  );

  static const LinearGradient sosGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF4757), Color(0xFFCC2233)],
  );

  static const LinearGradient heartGradient = LinearGradient(
    colors: [Color(0xFFFF6B8A), Color(0xFFFF3358)],
  );

  static const LinearGradient bpGradient = LinearGradient(
    colors: [Color(0xFF6B9FFF), Color(0xFF3366FF)],
  );

  static const LinearGradient spo2Gradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF00838F)],
  );

  static const LinearGradient stepsGradient = LinearGradient(
    colors: [Color(0xFF00C896), Color(0xFF006C51)],
  );

  static const LinearGradient gpsGradient = LinearGradient(
    colors: [Color(0xFFFFB347), Color(0xFFE8880A)],
  );
}
