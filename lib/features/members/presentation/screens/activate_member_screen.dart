import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/activation.dart';
import '../providers/member_providers.dart';

/// Reached via a `tayo://activate/<token>` link. Lets a placeholder member
/// (e.g. a child added by a parent) create their own account and take over
/// that existing member profile.
class ActivateMemberScreen extends ConsumerStatefulWidget {
  const ActivateMemberScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ActivateMemberScreen> createState() => _ActivateMemberScreenState();
}

class _ActivateMemberScreenState extends ConsumerState<ActivateMemberScreen> {
  late Future<ActivationPreview> _previewFuture;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _previewFuture = ref.read(activationRepositoryProvider).preview(widget.token);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(pendingDeepLinkProvider.notifier).state =
          Uri(scheme: 'tayo', host: 'activate', path: '/${widget.token}');
      if (ref.read(authControllerProvider).status == AuthStatus.unknown) {
        ref.read(authControllerProvider.notifier).checkAuthStatus();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _dismiss() {
    ref.read(pendingDeepLinkProvider.notifier).state = null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).claimActivation(
            token: widget.token,
            email: _emailController.text.trim(),
            password: _passwordController.text,
            passwordConfirmation: _confirmController.text,
          );
      _dismiss();
      if (mounted) context.go('/home');
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: authState.status == AuthStatus.authenticated
              ? _SignOutFirst(onSignOut: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                })
              : FutureBuilder<ActivationPreview>(
                  future: _previewFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError || snapshot.data?.isValid == false) {
                      return _InvalidLink(onDismiss: () {
                        _dismiss();
                        context.go('/welcome');
                      });
                    }

                    final preview = snapshot.data!;

                    return Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            'Create your account, ${preview.memberName}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            preview.householdName != null
                                ? "You're joining ${preview.householdName}"
                                : 'Finish setting up your profile',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 24),
                          if (_errorMessage != null) ...[
                            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                          ],
                          AppTextField(
                            label: 'Email address',
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
                            controller: _passwordController,
                            obscureText: true,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) {
                              if (value == null || value.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Confirm password',
                            controller: _confirmController,
                            obscureText: true,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) {
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: 'Create account',
                            isLoading: _isSubmitting,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _SignOutFirst extends StatelessWidget {
  const _SignOutFirst({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.info_outline_rounded, size: 48, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        Text(
          "You're already signed in. Sign out to activate this profile with its own account.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Sign out', onPressed: onSignOut),
      ],
    );
  }
}

class _InvalidLink extends StatelessWidget {
  const _InvalidLink({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.link_off_rounded, size: 48, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        Text(
          'This activation link has expired or was already used.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Continue', onPressed: onDismiss),
      ],
    );
  }
}
