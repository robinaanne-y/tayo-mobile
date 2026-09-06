import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/invitation.dart';
import '../providers/household_providers.dart';

/// Reached via a `tayo://invite/<token>` link (or a router redirect that
/// stashed one). Shows a preview of the household being joined, then either
/// routes an unauthenticated visitor to sign in/up first, or lets an
/// authenticated one join directly.
class JoinHouseholdScreen extends ConsumerStatefulWidget {
  const JoinHouseholdScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<JoinHouseholdScreen> createState() => _JoinHouseholdScreenState();
}

class _JoinHouseholdScreenState extends ConsumerState<JoinHouseholdScreen> {
  late Future<InvitationPreview> _previewFuture;
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _previewFuture = ref.read(invitationRepositoryProvider).preview(widget.token);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Stash this token so that if the user has to detour through
      // /login first, the redirect logic brings them back here afterward.
      ref.read(pendingDeepLinkProvider.notifier).state =
          Uri(scheme: 'tayo', host: 'invite', path: '/${widget.token}');
      if (ref.read(authControllerProvider).status == AuthStatus.unknown) {
        ref.read(authControllerProvider.notifier).checkAuthStatus();
      }
    });
  }

  void _dismiss() {
    ref.read(pendingDeepLinkProvider.notifier).state = null;
  }

  Future<void> _join() async {
    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      await ref.read(invitationRepositoryProvider).accept(widget.token);
      await ref.read(authControllerProvider.notifier).refreshUser();
      _dismiss();
      if (mounted) context.go('/home');
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated =
        ref.watch(authControllerProvider).status == AuthStatus.authenticated;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<InvitationPreview>(
            future: _previewFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError || snapshot.data?.isValid == false) {
                return _InvalidLink(onDismiss: () {
                  _dismiss();
                  context.go(isAuthenticated ? '/home' : '/welcome');
                });
              }

              final preview = snapshot.data!;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🏡', style: TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "You're invited to join",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview.householdName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'as ${preview.role.label}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),
                  if (_errorMessage != null) ...[
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                  ],
                  if (isAuthenticated) ...[
                    PrimaryButton(
                      label: 'Join ${preview.householdName}',
                      isLoading: _isJoining,
                      onPressed: _join,
                    ),
                  ] else ...[
                    PrimaryButton(
                      label: 'Sign in to join',
                      onPressed: () => context.go('/login'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        _dismiss();
                        context.go('/welcome');
                      },
                      child: const Text('Not now'),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
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
          'This invite link has expired or was already used.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Continue', onPressed: onDismiss),
      ],
    );
  }
}
