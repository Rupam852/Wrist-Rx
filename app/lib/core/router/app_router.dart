import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/ai/ai_chat_screen.dart';
import '../../features/ai/ai_onboarding_screen.dart';
import '../../features/profile/profile_settings_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/sos_settings_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../shared/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const AiOnboardingScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileSettingsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/sos-settings', builder: (_, __) => const SosSettingsScreen()),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),

      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/ai', builder: (_, __) => const AiChatScreen()),
        ],
      ),
    ],
  );
});
