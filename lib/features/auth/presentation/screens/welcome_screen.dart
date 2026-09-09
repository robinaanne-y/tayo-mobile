import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/screens/qr_scan_screen.dart';

class _Slide {
  const _Slide({
    required this.emoji,
    required this.color,
    required this.title,
    required this.body,
  });

  final String emoji;
  final Color color;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    emoji: '🏡',
    color: AppColors.primary,
    title: 'Your family, in sync',
    body: 'Schedules, meals, groceries, and more — all in one calm, '
        'friendly place your whole family will love opening every morning.',
  ),
  _Slide(
    emoji: '🔔',
    color: AppColors.skyBlue,
    title: 'Never miss a thing',
    body: 'Share calendars, track chores, plan trips, and manage permission '
        'requests — all coordinated across every family member.',
  ),
  _Slide(
    emoji: '🍽️',
    color: AppColors.accent,
    title: 'From meals to memories',
    body: "Plan the week's dinners, build grocery lists together, and "
        'celebrate the moments that matter most.',
  ),
];

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _current = 0;

  void _next() {
    if (_current < _slides.length - 1) {
      setState(() => _current++);
    } else {
      context.go('/login');
    }
  }

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_current];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _openScanner,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    tooltip: 'Scan invite code',
                    color: AppColors.textSecondary,
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: slide.color.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: slide.color.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(slide.emoji, style: const TextStyle(fontSize: 72)),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 26),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      slide.body,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _current;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? slide.color : AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(backgroundColor: slide.color),
                      child: Text(
                        _current < _slides.length - 1 ? 'Continue' : 'Get started',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: const Text(
                          'Sign in',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
