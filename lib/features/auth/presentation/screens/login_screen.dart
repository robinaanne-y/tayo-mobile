import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/utils/accessibility.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../providers/auth_controller.dart';

enum _AuthMode { login, signup }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.startInSignup = false});

  /// Opens on the Sign up tab, e.g. from the welcome screen's "Get started".
  final bool startInSignup;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  late _AuthMode _mode = widget.startInSignup ? _AuthMode.signup : _AuthMode.login;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_mode == _AuthMode.login) {
        await ref.read(authControllerProvider.notifier).login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
      } else {
        await ref.read(authControllerProvider.notifier).register(
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
              passwordConfirmation: _confirmController.text,
            );
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _AuthMode.login;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton.filled(
                    tooltip: 'Back',
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/welcome'),
                    style: IconButton.styleFrom(
                      backgroundColor: context.colors.primarySoft,
                      foregroundColor: context.colors.textPrimary,
                    ),
                    icon: const Icon(LucideIcons.chevronLeft, size: 20),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🏡', style: TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLogin ? 'Welcome back' : 'Create account',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            isLogin
                                ? 'Sign in to your household'
                                : 'Set up your family account',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.colors.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: _AuthMode.values.map((mode) {
                      final selected = mode == _mode;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _switchMode(mode),
                          child: AnimatedContainer(
                            duration: context.motionDuration(const Duration(milliseconds: 150)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? context.colors.surface : null,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              mode == _AuthMode.login ? 'Sign in' : 'Sign up',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: selected
                                    ? context.colors.primary
                                    : context.colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                ],
                if (!isLogin) ...[
                  AppTextField(
                    label: 'Your name',
                    hint: 'e.g. Maria',
                    labelAbove: true,
                    controller: _nameController,
                    autofillHints: const [AutofillHints.name],
                    validator: (value) {
                      if (isLogin) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                AppTextField(
                  label: 'Email address',
                  hint: 'you@example.com',
                  labelAbove: true,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password',
                  hint: '••••••••',
                  labelAbove: true,
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  suffixIcon: _VisibilityToggle(
                    obscured: _obscurePassword,
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  autofillHints: [
                    isLogin ? AutofillHints.password : AutofillHints.newPassword,
                  ],
                  validator: (value) {
                    if (isLogin) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      return null;
                    }
                    if (value == null || value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                if (!isLogin) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Confirm password',
                    hint: '••••••••',
                    labelAbove: true,
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    suffixIcon: _VisibilityToggle(
                      obscured: _obscureConfirm,
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) {
                      if (isLogin) return null;
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: isLogin ? 'Sign in' : 'Create account',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({required this.obscured, required this.onPressed});

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      onPressed: onPressed,
      color: context.colors.icon,
      icon: Icon(obscured ? LucideIcons.eye : LucideIcons.eyeOff, size: 20),
    );
  }
}
