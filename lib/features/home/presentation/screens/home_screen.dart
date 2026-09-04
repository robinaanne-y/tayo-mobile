import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

/// Foundation placeholder. This becomes the family feed aggregation screen
/// in a later phase (today's schedule, notes, requests, meals, etc.).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final household = user?.households.isNotEmpty == true
        ? user!.households.first
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(household?.name ?? 'Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, ${user?.name ?? ''}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                "What's happening with your family today.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 32),
              Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: household == null
                      ? null
                      : () => context.push('/home/members', extra: household.id),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.groups_rounded, color: AppColors.mint),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Manage household members',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Text(
                    "Today's schedule, notes and requests will\nshow up here in a later phase.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
