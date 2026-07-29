import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(userModelProvider.notifier).signInWithGoogle();
      if (!mounted) return;

      if (result.isNewUser) {
        context.go('/onboarding');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
          ),
          // Subtle glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // Logo
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 46),
                  ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.5, 0.5)),
                  const SizedBox(height: 24),
                  Text(
                    'Wrist Rx',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 10),
                  Text(
                    'Your personal health companion',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurfaceDark,
                      height: 1.5,
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                  const Spacer(flex: 2),
                  // Feature highlights
                  ...[
                    _FeatureTile(icon: Icons.favorite_rounded, color: AppColors.heartRateColor, text: 'Real-time Heart Rate & BP'),
                    _FeatureTile(icon: Icons.directions_walk_rounded, color: AppColors.stepsColor, text: 'Smart Pedometer & GPS'),
                    _FeatureTile(icon: Icons.psychology_rounded, color: AppColors.gpsColor, text: 'AI Health Assistant'),
                  ].asMap().entries.map((e) =>
                    e.value.animate().fadeIn(delay: Duration(milliseconds: 500 + e.key * 100)).slideX(begin: -0.3, end: 0)
                  ),
                  const Spacer(flex: 3),
                  // Google Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black45),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  'https://www.google.com/favicon.ico',
                                  width: 22,
                                  height: 22,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 28, color: Colors.blue),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.5, end: 0),
                  const SizedBox(height: 16),
                  Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white30,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _FeatureTile({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}
