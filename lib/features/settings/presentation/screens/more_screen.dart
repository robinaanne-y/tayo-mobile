import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../shared/screens/coming_soon_screen.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../../households/presentation/screens/household_settings_screen.dart';

/// The 5th bottom-nav tab, at `/more` — a settings hub, distinct from
/// Home's own "More" grid section (Chores/Map/Permissions/Trips). Mostly a
/// menu that links out to existing screens rather than reimplementing them.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  Future<void> _openDefaultHouseholdSheet(BuildContext context) async {
    await showAppBottomSheet<void>(
      context: context,
      builder: (context) => const _DefaultHouseholdSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(currentHouseholdProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('More', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            Text('Appearance', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
              child: SegmentedButton<ThemeMode>(
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Light', maxLines: 1, softWrap: false),
                    ),
                    icon: Icon(LucideIcons.sun, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Dark', maxLines: 1, softWrap: false),
                    ),
                    icon: Icon(LucideIcons.moon, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('System', maxLines: 1, softWrap: false),
                    ),
                    icon: Icon(LucideIcons.monitor, size: 16),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (selection) =>
                    ref.read(themeModeProvider.notifier).setThemeMode(selection.first),
              ),
            ),
            const SizedBox(height: 24),
            _MoreListTile(
              icon: LucideIcons.house,
              label: 'Default household',
              value: household?.name,
              onTap: () => _openDefaultHouseholdSheet(context),
            ),
            const SizedBox(height: 8),
            _MoreListTile(
              icon: LucideIcons.user,
              label: 'Profile',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _MoreListTile(
              icon: LucideIcons.users,
              label: 'Family',
              onTap: () => context.push('/family'),
            ),
            const SizedBox(height: 8),
            _MoreListTile(
              icon: LucideIcons.settings,
              label: 'Household settings',
              onTap: household == null
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => HouseholdSettingsScreen(household: household)),
                      ),
            ),
            const SizedBox(height: 8),
            _MoreListTile(
              icon: LucideIcons.shieldCheck,
              label: 'Account settings',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ComingSoonScreen(
                    title: 'Account settings',
                    icon: LucideIcons.shieldCheck,
                    message: 'Password, connected devices, and other account-level '
                        'settings are on their way.',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreListTile extends StatelessWidget {
  const _MoreListTile({
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            if (value != null) ...[
              Text(
                value!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(LucideIcons.chevronRight, size: 16, color: context.colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _DefaultHouseholdSheet extends ConsumerWidget {
  const _DefaultHouseholdSheet();

  Future<void> _select(BuildContext context, WidgetRef ref, int? householdId) async {
    try {
      await ref.read(authControllerProvider.notifier).updateDefaultHousehold(householdId: householdId);
      if (context.mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final households = user?.households ?? const [];
    final defaultId = user?.defaultHouseholdId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Default household', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Which household should open first when you launch the app?',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _DefaultHouseholdOption(
          label: 'Use first household automatically',
          selected: defaultId == null,
          onTap: () => _select(context, ref, null),
        ),
        const SizedBox(height: 8),
        for (final household in households) ...[
          _DefaultHouseholdOption(
            label: household.name,
            selected: household.id == defaultId,
            onTap: () => _select(context, ref, household.id),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _DefaultHouseholdOption extends StatelessWidget {
  const _DefaultHouseholdOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? context.colors.primary.withValues(alpha: 0.08) : context.colors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? context.colors.primary.withValues(alpha: 0.4) : context.colors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            if (selected) Icon(LucideIcons.check, color: context.colors.primary, size: 18),
          ],
        ),
      ),
    );
  }
}
