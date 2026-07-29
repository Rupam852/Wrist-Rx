import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_provider.dart';

class AiOnboardingScreen extends ConsumerStatefulWidget {
  const AiOnboardingScreen({super.key});

  @override
  ConsumerState<AiOnboardingScreen> createState() => _AiOnboardingScreenState();
}

class _AiOnboardingScreenState extends ConsumerState<AiOnboardingScreen> {
  int _step = 0;
  bool _isLoading = false;
  int? _age;
  String? _gender;
  List<String> _conditions = [];
  List<String> _goals = [];
  String? _activityLevel;

  final _ageController = TextEditingController();

  final _conditions_options = ['Diabetes', 'Hypertension', 'Heart Disease', 'Asthma', 'None'];
  final _goals_options = ['Lose Weight', 'Improve Fitness', 'Monitor Heart Health', 'Manage BP', 'Better Sleep'];
  final _activity_options = [
    ('Sedentary', 'sedentary', Icons.chair_rounded),
    ('Lightly Active', 'lightly_active', Icons.directions_walk_rounded),
    ('Moderately Active', 'moderately_active', Icons.directions_run_rounded),
    ('Very Active', 'very_active', Icons.fitness_center_rounded),
  ];

  Future<void> _finish() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(userModelProvider.notifier).saveOnboarding({
        'age': _age,
        'gender': _gender,
        'conditions': _conditions,
        'goals': _goals,
        'activityLevel': _activityLevel,
      });
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Progress
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Step ${_step + 1} of 5',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.go('/home'),
                          child: Text('Skip', style: TextStyle(color: AppColors.onSurfaceDark)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_step + 1) / 5,
                      backgroundColor: Colors.white10,
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 6,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildStep(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _StepWrapper(
          question: '🤖 Hi! I\'m your AI health assistant.\nHow old are you?',
          subtitle: 'This helps me give you age-appropriate health insights.',
          child: Column(
            children: [
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Enter your age',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 20),
                  suffix: Text('years', style: TextStyle(color: AppColors.onSurfaceDark)),
                ),
                onChanged: (v) => _age = int.tryParse(v),
              ),
              const Spacer(),
              _NextButton(onNext: () => setState(() => _step++)),
            ],
          ),
        );
      case 1:
        return _StepWrapper(
          question: '⚧ What is your gender?',
          subtitle: 'Helps personalize your health recommendations.',
          child: Column(
            children: [
              ...['Male', 'Female', 'Other'].map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _gender = g.toLowerCase()),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _gender == g.toLowerCase()
                          ? AppColors.primary.withOpacity(0.2)
                          : AppColors.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _gender == g.toLowerCase() ? AppColors.primary : Colors.white12,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(_gender == g.toLowerCase() ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: _gender == g.toLowerCase() ? AppColors.primary : Colors.white30),
                        const SizedBox(width: 12),
                        Text(g, style: TextStyle(
                          color: _gender == g.toLowerCase() ? Colors.white : AppColors.onSurfaceDark,
                          fontWeight: FontWeight.w500, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              )),
              const Spacer(),
              _NextButton(onNext: () => setState(() => _step++)),
            ],
          ),
        );
      case 2:
        return _StepWrapper(
          question: '🏥 Any medical conditions?',
          subtitle: 'Select all that apply.',
          child: Column(
            children: [
              ..._conditions_options.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => setState(() {
                    if (_conditions.contains(c)) _conditions.remove(c);
                    else _conditions.add(c);
                  }),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _conditions.contains(c) ? AppColors.primary.withOpacity(0.2) : AppColors.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _conditions.contains(c) ? AppColors.primary : Colors.white12,
                        width: 1.5,
                      ),
                    ),
                    child: Row(children: [
                      Icon(_conditions.contains(c) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: _conditions.contains(c) ? AppColors.primary : Colors.white30),
                      const SizedBox(width: 12),
                      Text(c, style: TextStyle(
                        color: _conditions.contains(c) ? Colors.white : AppColors.onSurfaceDark,
                        fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              )),
              const Spacer(),
              _NextButton(onNext: () => setState(() => _step++)),
            ],
          ),
        );
      case 3:
        return _StepWrapper(
          question: '🎯 What are your health goals?',
          subtitle: 'Select all that apply.',
          child: Column(
            children: [
              ..._goals_options.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => setState(() {
                    if (_goals.contains(g)) _goals.remove(g);
                    else _goals.add(g);
                  }),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _goals.contains(g) ? AppColors.primary.withOpacity(0.2) : AppColors.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _goals.contains(g) ? AppColors.primary : Colors.white12, width: 1.5),
                    ),
                    child: Row(children: [
                      Icon(_goals.contains(g) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: _goals.contains(g) ? AppColors.primary : Colors.white30),
                      const SizedBox(width: 12),
                      Text(g, style: TextStyle(
                        color: _goals.contains(g) ? Colors.white : AppColors.onSurfaceDark,
                        fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              )),
              const Spacer(),
              _NextButton(onNext: () => setState(() => _step++)),
            ],
          ),
        );
      case 4:
        return _StepWrapper(
          question: '⚡ How active are you?',
          subtitle: 'Choose your typical daily activity level.',
          child: Column(
            children: [
              ..._activity_options.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _activityLevel = a.$2),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _activityLevel == a.$2 ? AppColors.primary.withOpacity(0.2) : AppColors.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _activityLevel == a.$2 ? AppColors.primary : Colors.white12, width: 1.5),
                    ),
                    child: Row(children: [
                      Icon(a.$3, color: _activityLevel == a.$2 ? AppColors.primary : Colors.white30, size: 22),
                      const SizedBox(width: 12),
                      Text(a.$1, style: TextStyle(
                        color: _activityLevel == a.$2 ? Colors.white : AppColors.onSurfaceDark,
                        fontWeight: FontWeight.w500, fontSize: 16)),
                    ]),
                  ),
                ),
              )),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _finish,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Get Started 🚀'),
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox();
    }
  }
}

class _StepWrapper extends StatelessWidget {
  final String question;
  final String subtitle;
  final Widget child;
  const _StepWrapper({required this.question, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(question,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white, fontWeight: FontWeight.w700, height: 1.3,
          ),
        ).animate().fadeIn().slideY(begin: 0.2, end: 0),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceDark))
            .animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 28),
        Expanded(child: child),
      ],
    );
  }
}

class _NextButton extends StatelessWidget {
  final VoidCallback onNext;
  const _NextButton({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onNext,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
          Text('Next'),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, size: 18),
        ]),
      ),
    );
  }
}
