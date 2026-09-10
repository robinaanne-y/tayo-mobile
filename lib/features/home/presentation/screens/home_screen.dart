import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../households/domain/household.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../../members/presentation/providers/member_providers.dart';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Foundation placeholder. This becomes the family feed aggregation screen
/// in a later phase (today's schedule, notes, requests, meals, etc.).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String get _dateLabel {
    final now = DateTime.now();
    return '${_weekdayNames[now.weekday - 1]}, ${_monthNames[now.month - 1]} ${now.day}';
  }

  ({String text, String emoji}) get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return (text: 'Good morning!', emoji: '☀️');
    if (hour < 17) return (text: 'Good afternoon!', emoji: '🌤️');
    return (text: 'Good evening!', emoji: '🌙');
  }

  void _notComingYet(BuildContext context) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Coming soon.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(currentHouseholdProvider);
    final greeting = _greeting;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_dateLabel, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 2),
                        Text(
                          '${greeting.text} ${greeting.emoji}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    tooltip: 'Notifications',
                    onPressed: null,
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () async {
                      // Resolve after the sheet has fully closed, using this
                      // screen's own (stable) context rather than the
                      // sheet's — popping first and immediately navigating
                      // from the sheet's own context is unreliable since
                      // that context is being torn down.
                      final result = await showAppBottomSheet<Object>(
                        context: context,
                        builder: (context) => const _HouseholdSwitcherSheet(),
                      );
                      if (!context.mounted) return;
                      if (result is int) {
                        ref.read(selectedHouseholdIdProvider.notifier).state = result;
                      } else if (result == 'create') {
                        context.go('/create-household');
                      } else if (result == 'logout') {
                        ref.read(authControllerProvider.notifier).logout();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🏡', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            household?.name ?? 'Household',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('🏡', style: TextStyle(fontSize: 36)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome to your household!',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "This is your family's home base. Add events, plan "
                          'meals, and coordinate everything in one calm place.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'GET STARTED'),
                  const SizedBox(height: 8),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _GetStartedRow(
                          icon: Icons.groups_rounded,
                          label: 'Invite family members',
                          onTap: () => context.go('/family'),
                        ),
                        const Divider(height: 1),
                        _GetStartedRow(
                          icon: Icons.calendar_month_rounded,
                          label: 'Add your first event',
                          onTap: () => context.go('/calendar'),
                        ),
                        const Divider(height: 1),
                        _GetStartedRow(
                          icon: Icons.restaurant_rounded,
                          label: "Plan this week's meals",
                          onTap: () => context.go('/meals'),
                        ),
                        const Divider(height: 1),
                        _GetStartedRow(
                          icon: Icons.shopping_basket_rounded,
                          label: 'Start your grocery list',
                          onTap: () => context.go('/groceries'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text("Today's Schedule", style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _EmptyStateCard(
                    emoji: '📅',
                    title: 'No events today',
                    message: 'Your calendar is clear. Add an event for you or '
                        'someone in the family.',
                    buttonLabel: 'Add event',
                    onPressed: () => context.go('/calendar'),
                  ),
                  const SizedBox(height: 24),
                  Text('Family Notes', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _EmptyStateCard(
                    emoji: '📝',
                    title: 'No notes yet',
                    message: 'Leave a quick message for your family — '
                        'reminders, encouragement, or just a hello.',
                    buttonLabel: 'Leave a note',
                    onPressed: () => _notComingYet(context),
                  ),
                  const SizedBox(height: 24),
                  Text("Today's Meals", style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _EmptyStateCard(
                    emoji: '🍽️',
                    title: 'No meals planned yet',
                    message: "Your family hasn't planned dinner yet. Set up "
                        "this week's meal schedule.",
                    buttonLabel: 'Plan meals',
                    onPressed: () => context.go('/meals'),
                  ),
                  const SizedBox(height: 24),
                  Text('Groceries', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _EmptyStateCard(
                    emoji: '🛒',
                    title: 'No groceries yet',
                    message: 'Start your shared grocery list so the whole '
                        'family can chip in.',
                    buttonLabel: 'Add items',
                    onPressed: () => context.go('/groceries'),
                  ),
                  const SizedBox(height: 24),
                  Text('Upcoming Trip', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _EmptyStateCard(
                    emoji: '✈️',
                    title: 'No upcoming trips',
                    message: 'Plan a family trip — camping, beach, or even a '
                        "staycation — and keep everyone's itinerary in one place.",
                    buttonLabel: 'Plan a trip',
                    onPressed: () => _notComingYet(context),
                  ),
                  const SizedBox(height: 24),
                  Text('Household Status', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  const _HouseholdStatusRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GetStartedRow extends StatelessWidget {
  const _GetStartedRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.border),
          ],
        ),
      ),
    );
  }
}

/// Shared "nothing here yet" card used for every not-yet-built Home
/// section (schedule, notes, meals, groceries, trips).
class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.emoji,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String emoji;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

const _householdSwitcherEmojis = ['🏡', '⭐', '🌿', '🍀', '☀️'];

/// Opened by tapping the household pill. Lists every household the user
/// belongs to and lets them pick which one is "active" app-wide, plus the
/// only paths out of here that exist today: creating a new household, or
/// logging out (there's no profile/settings screen yet to house that).
///
/// Pops with the chosen household's id (int), the string 'create', or the
/// string 'logout' — the caller acts on it using its own stable context,
/// rather than this sheet navigating from its own context, which is
/// already being torn down by the time `pop()` returns.
class _HouseholdSwitcherSheet extends ConsumerWidget {
  const _HouseholdSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final households = ref.watch(authControllerProvider).user?.households ?? const [];
    final current = ref.watch(currentHouseholdProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Households', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        for (var i = 0; i < households.length; i++) ...[
          _HouseholdRow(
            household: households[i],
            emoji: _householdSwitcherEmojis[i % _householdSwitcherEmojis.length],
            colorIndex: i,
            selected: households[i].id == current?.id,
            onTap: () => Navigator.of(context).pop(households[i].id),
          ),
          const SizedBox(height: 10),
        ],
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).pop('create'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Create or join a household',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop('logout'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Log out'),
          ),
        ),
      ],
    );
  }
}

class _HouseholdRow extends StatelessWidget {
  const _HouseholdRow({
    required this.household,
    required this.emoji,
    required this.colorIndex,
    required this.selected,
    required this.onTap,
  });

  final Household household;
  final String emoji;
  final int colorIndex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.memberColor(colorIndex);
    final count = household.memberCount;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(household.name, style: Theme.of(context).textTheme.titleMedium),
                  if (count != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$count ${count == 1 ? 'member' : 'members'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary)
            else
              const SizedBox(width: 24, height: 24),
          ],
        ),
      ),
    );
  }
}

/// A quick-glance row of household members. No real "where is everyone"
/// data exists yet (that's Phase 8, deferred, and privacy-sensitive) — this
/// shows who's in the household via their avatar and a decorative color
/// dot, without fabricating a location.
class _HouseholdStatusRow extends ConsumerWidget {
  const _HouseholdStatusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(currentHouseholdMembersProvider).valueOrNull ?? const [];
    if (members.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: members.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final member = members[index];
          final color = AppColors.memberColor(index);
          return SizedBox(
            width: 64,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    MemberAvatar(name: member.name, colorIndex: index, size: 56),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
