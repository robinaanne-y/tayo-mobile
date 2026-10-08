import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_list_row.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../../shared/widgets/participant_avatar_stack.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/screens/coming_soon_screen.dart';
import '../../../announcements/domain/announcement.dart';
import '../../../announcements/presentation/announcement_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../calendar/domain/event.dart';
import '../../../calendar/presentation/providers/event_providers.dart';
import '../../../family_notes/domain/family_note.dart';
import '../../../family_notes/presentation/family_note_providers.dart';
import '../../../groceries/presentation/providers/grocery_providers.dart';
import '../../../households/domain/household.dart';
import '../../../households/presentation/household_visuals.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../../meals/domain/meal_plan_item.dart';
import '../../../meals/domain/meal_request.dart';
import '../../../meals/presentation/providers/meal_providers.dart';
import '../../../meals/presentation/screens/meals_screen.dart' show MealRequestDetailSheet;
import '../../../members/domain/member.dart';
import '../../../members/presentation/providers/member_providers.dart';
import '../../../reminders/domain/reminder.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';
import '../../../requests/domain/permission_request.dart';
import '../../../requests/presentation/providers/permission_request_providers.dart';
import '../../../requests/presentation/screens/requests_screen.dart' show RequestDetailSheet;
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../../trips/presentation/providers/trip_providers.dart';
import '../../../trips/presentation/screens/trip_detail_screen.dart';

/// `_AttentionItem.id`s the viewer has already seen in the bell sheet, this
/// app session — the bell badge number only counts items *not* in this set,
/// so opening the bell clears it even for a request still awaiting the
/// viewer's action (it becomes a "new since last viewed" counter, not a
/// "work remaining" counter). "Needs Your Attention" itself is unaffected —
/// it keeps showing every actionable item regardless of whether it's been
/// seen, since that section's job is "here's what still needs doing," not
/// "here's what's new." In-memory only: resets on a fresh app launch.
final _seenAttentionItemIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Base hues for note cards — a light tint is used as the background, a
/// darker shade of the same hue as the border, so each note reads as one
/// coherent color rather than a flat pastel block. A function (not a
/// `const` list) because `accent`/`primary` are theme-dependent.
List<Color> _kNoteColors(BuildContext context) => [
      AppColors.softYellow,
      context.colors.accent,
      AppColors.skyBlue,
      AppColors.lavender,
      context.colors.primary,
    ];

String _timeLeftLabel(DateTime expiresAt) {
  final diff = expiresAt.difference(DateTime.now());
  if (diff.isNegative) return 'Expired';
  if (diff.inHours >= 1) return '${diff.inHours}h left';
  return '${diff.inMinutes.clamp(1, 59)}m left';
}

String _announcementTimeLabel(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${_monthNames[createdAt.month - 1].substring(0, 3)} ${createdAt.day}';
}

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Mirrors `MealsScreen`'s own `_canManageMeals`: when the household has
/// designated a meal approver, that one member fully replaces the role
/// check, so a plain Owner/Adult who isn't the approver must NOT be shown
/// as able to act on a meal request here either.
bool _canManageMealsFor(Household? household, int? myMemberId) {
  if (household == null) return false;
  final approverId = household.mealApproverMemberId;
  if (approverId != null) return myMemberId == approverId;
  return household.myRole == 'owner' || household.myRole == 'adult';
}

/// A normalized "needs my attention" row — permission requests and meal
/// requests have different domain models and detail sheets, but Home shows
/// them in one combined list (the bell sheet, "Needs Your Attention"), so
/// each gets mapped to this shape rather than merging the two models.
/// `onApprove`/`onDecline` are null for a row the viewer can't act on (it's
/// their own request, surfaced only so they notice the outcome) — the card
/// then shows a single "Review" affordance instead of the three-button row.
class _AttentionItem {
  const _AttentionItem({
    required this.id,
    required this.icon,
    required this.iconBackground,
    required this.description,
    required this.onReview,
    this.onApprove,
    this.onDecline,
    this.onAcknowledge,
  });

  /// A stable key ("permission-5", "meal-12") distinguishing requests of
  /// different types that happen to share a numeric id — used to dedupe
  /// which items have already been auto-acknowledged this sheet session.
  final String id;
  final IconData icon;
  final Color iconBackground;
  final String description;
  final Future<void> Function(BuildContext context, WidgetRef ref) onReview;
  final Future<void> Function(BuildContext context, WidgetRef ref)? onApprove;
  final Future<void> Function(BuildContext context, WidgetRef ref)? onDecline;

  /// Set only for a resolved request the viewer hasn't acknowledged yet —
  /// called automatically once the bell sheet shows it (see
  /// `_NotificationsSheet`), so simply opening the bell is enough to clear
  /// it, rather than requiring the viewer to tap into its detail sheet.
  final Future<void> Function(WidgetRef ref)? onAcknowledge;

  bool get canAct => onApprove != null && onDecline != null;
}

_AttentionItem _permissionAttentionItem(PermissionRequest request, {required bool canActOnIt}) {
  Future<void> review(BuildContext context, WidgetRef ref) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;
    await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => RequestDetailSheet(householdId: household.id, request: request),
    );
    // Unconditional: viewing a resolved request silently acknowledges it,
    // which this caller has no explicit signal for.
    ref.invalidate(currentHouseholdRequestsProvider);
  }

  Future<void> respond(WidgetRef ref, {required bool approve}) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;
    final repository = ref.read(permissionRequestRepositoryProvider);
    if (approve) {
      await repository.approve(householdId: household.id, requestId: request.id);
    } else {
      await repository.decline(householdId: household.id, requestId: request.id);
    }
    ref.invalidate(currentHouseholdRequestsProvider);
  }

  final description = request.status == RequestStatus.pending
      ? '${request.requesterName} requested permission for "${request.title}"'
      : 'Your request "${request.title}" was '
          '${request.status == RequestStatus.approved ? 'approved' : 'declined'}';

  return _AttentionItem(
    id: 'permission-${request.id}',
    icon: LucideIcons.shield,
    iconBackground: AppColors.coral,
    description: description,
    onReview: review,
    onApprove: canActOnIt ? (context, ref) => respond(ref, approve: true) : null,
    onDecline: canActOnIt ? (context, ref) => respond(ref, approve: false) : null,
    onAcknowledge: request.needsRequesterAttention
        ? (ref) async {
            final household = ref.read(currentHouseholdProvider);
            if (household == null) return;
            await ref
                .read(permissionRequestRepositoryProvider)
                .acknowledge(householdId: household.id, requestId: request.id);
            ref.invalidate(currentHouseholdRequestsProvider);
          }
        : null,
  );
}

_AttentionItem _mealAttentionItem(MealRequest request, {required bool canActOnIt}) {
  Future<void> review(BuildContext context, WidgetRef ref) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;
    await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => MealRequestDetailSheet(householdId: household.id, request: request),
    );
    ref.invalidate(currentHouseholdMealRequestsProvider);
    // Approving can create/update a meal plan item for today.
    ref.invalidate(currentHouseholdTodaysMealsProvider);
  }

  Future<void> respond(WidgetRef ref, {required bool approve}) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;
    final repository = ref.read(mealRequestRepositoryProvider);
    if (approve) {
      await repository.approve(householdId: household.id, requestId: request.id);
    } else {
      await repository.decline(householdId: household.id, requestId: request.id);
    }
    ref.invalidate(currentHouseholdMealRequestsProvider);
    ref.invalidate(currentHouseholdTodaysMealsProvider);
  }

  final description = request.status == RequestStatus.pending
      ? '${request.requesterName} requested ${request.title} for '
          '${_homeMealSlotLabel(request.requestedSlot).toLowerCase()}'
      : 'Your meal request "${request.title}" was '
          '${request.status == RequestStatus.approved ? 'approved' : 'declined'}';

  return _AttentionItem(
    id: 'meal-${request.id}',
    icon: LucideIcons.utensils,
    iconBackground: AppColors.lavender,
    description: description,
    onReview: review,
    onApprove: canActOnIt ? (context, ref) => respond(ref, approve: true) : null,
    onDecline: canActOnIt ? (context, ref) => respond(ref, approve: false) : null,
    onAcknowledge: request.needsRequesterAttention
        ? (ref) async {
            final household = ref.read(currentHouseholdProvider);
            if (household == null) return;
            await ref
                .read(mealRequestRepositoryProvider)
                .acknowledge(householdId: household.id, requestId: request.id);
            ref.invalidate(currentHouseholdMealRequestsProvider);
          }
        : null,
  );
}

/// Permission/meal requests the viewer can act on right now (pending,
/// never their own request) — this is the *only* thing "Needs Your
/// Attention" and the bell badge count ever show; a resolved request never
/// appears here regardless of whether the requester has seen it yet (see
/// `_resolvedAttentionItems` for that). Permission requests and meal
/// requests use different "can manage" rules (meal requests respect a
/// per-household approver override — see `_canManageMealsFor`), so each
/// list is checked against its own flag rather than one shared one.
List<_AttentionItem> _actionableAttentionItems({
  required List<PermissionRequest> permissionRequests,
  required List<MealRequest> mealRequests,
  required int? myMemberId,
  required bool canManagePermissions,
  required bool canManageMeals,
}) {
  final items = <_AttentionItem>[];

  for (final r in permissionRequests) {
    final canActOnIt =
        canManagePermissions && r.status == RequestStatus.pending && r.requesterMemberId != myMemberId;
    if (canActOnIt) items.add(_permissionAttentionItem(r, canActOnIt: true));
  }

  for (final r in mealRequests) {
    final canActOnIt =
        canManageMeals && r.status == RequestStatus.pending && r.requesterMemberId != myMemberId;
    if (canActOnIt) items.add(_mealAttentionItem(r, canActOnIt: true));
  }

  return items;
}

/// The viewer's own requests that were just approved/declined and they
/// haven't acknowledged yet (the API's viewer-relative
/// `needs_requester_attention` field). Surfaced only in the bell sheet's
/// "Recently resolved" section, never in "Needs Your Attention" or the
/// badge count — there's nothing left to *do* with these, only to notice.
List<_AttentionItem> _resolvedAttentionItems({
  required List<PermissionRequest> permissionRequests,
  required List<MealRequest> mealRequests,
}) {
  final items = <_AttentionItem>[];

  for (final r in permissionRequests) {
    if (r.needsRequesterAttention) items.add(_permissionAttentionItem(r, canActOnIt: false));
  }

  for (final r in mealRequests) {
    if (r.needsRequesterAttention) items.add(_mealAttentionItem(r, canActOnIt: false));
  }

  return items;
}

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(currentHouseholdProvider);
    final greeting = _greeting;
    final householdColor = householdColorFromHex(context, household?.color);
    final householdEmoji = household?.emoji ?? kHouseholdEmojis.first;

    final myMemberId = ref.watch(authControllerProvider).user?.member?.id;
    final canManage = household?.myRole == 'owner' || household?.myRole == 'adult';
    final allRequests = ref.watch(currentHouseholdRequestsProvider).valueOrNull;
    final allMealRequests = ref.watch(currentHouseholdMealRequestsProvider).valueOrNull;
    final seenIds = ref.watch(_seenAttentionItemIdsProvider);
    final actionableCount = _actionableAttentionItems(
      permissionRequests: allRequests ?? const [],
      mealRequests: allMealRequests ?? const [],
      myMemberId: myMemberId,
      canManagePermissions: canManage,
      canManageMeals: _canManageMealsFor(household, myMemberId),
    ).where((item) => !seenIds.contains(item.id)).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: context.colors.surface,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(_dateLabel, style: Theme.of(context).textTheme.bodySmall),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${greeting.text} ${greeting.emoji}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Badge(
                      isLabelVisible: actionableCount > 0,
                      label: Text('$actionableCount'),
                      child: const Icon(LucideIcons.bell),
                    ),
                    tooltip: 'Notifications',
                    // Opens a lightweight sheet scoped to what's relevant
                    // to *this* viewer (see _NotificationsSheet) rather
                    // than pushing the full Permissions/Requests screen,
                    // which lists every household request regardless of
                    // viewer -- the bell is "what needs my attention", the
                    // Permissions tile is "browse/manage everything".
                    onPressed: () async {
                      final result = await showAppBottomSheet<String>(
                        context: context,
                        builder: (context) => const _NotificationsSheet(),
                      );
                      if (result == 'view-all' && context.mounted) context.push('/requests');
                    },
                  ),
                  // A fixed max width (not Flexible/Expanded) so this pill
                  // doesn't compete for flex space with the greeting column
                  // above — two equal-flex siblings would each get half the
                  // remaining row width, leaving the pill's unused half as a
                  // visible gap instead of sitting flush at the row's end.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: InkWell(
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
                          color: householdColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(householdEmoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                household?.name ?? 'Household',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  color: householdColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Icon(
                              LucideIcons.chevronDown,
                              color: householdColor,
                              size: 18,
                            ),
                          ],
                        ),
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
                  const _RemindersSection(),
                  const _TodaysScheduleSection(),
                  const SizedBox(height: 24),
                  Text('Needs Your Attention', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const _PendingRequestsSection(),
                  const SizedBox(height: 24),
                  const _FamilyNotesSection(),
                  const SizedBox(height: 24),
                  const _AnnouncementsSection(),
                  const SizedBox(height: 24),
                  const _TodaysMealsSection(),
                  const SizedBox(height: 24),
                  const _GroceriesSection(),
                  const SizedBox(height: 24),
                  const _TasksSection(),
                  const SizedBox(height: 24),
                  const _TripsSection(),
                  const SizedBox(height: 24),
                  Text('More', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const _MoreRow(),
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

/// Title + optional right-aligned text link, used above every Home section
/// that has a "see more" style action (schedule, notes, meals, groceries).
class _SectionHeaderRow extends StatelessWidget {
  const _SectionHeaderRow({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(actionLabel, style: TextStyle(color: context.colors.primary)),
        ),
      ],
    );
  }
}

/// Shared "nothing here yet" card used for every not-yet-built Home
/// section (schedule, meals, groceries, trips) and for "Needs Your
/// Attention", which has no action to offer when nothing needs review.
class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.emoji,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  final String emoji;
  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

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
          if (buttonLabel != null && onPressed != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(buttonLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Time-sensitive nudges computed server-side from existing data (no new
/// "reminder" rows are ever stored) — see ReminderComputer on the API
/// side. Unlike every other Home section, there is no empty-state card:
/// having no reminders is the normal, expected state, so this collapses
/// to nothing rather than showing an empty header.
class _RemindersSection extends ConsumerWidget {
  const _RemindersSection();

  void _open(BuildContext context, Reminder reminder) {
    switch (reminder.category) {
      case 'meal_planning':
        context.go('/meals');
      case 'grocery':
        context.go('/groceries');
      case 'trip_prep':
        if (reminder.tripId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: reminder.tripId!)),
          );
        } else {
          context.push('/trips');
        }
    }
  }

  IconData _iconFor(String category) => switch (category) {
        'meal_planning' => LucideIcons.utensils,
        'grocery' => LucideIcons.shoppingBag,
        'trip_prep' => LucideIcons.plane,
        _ => LucideIcons.bell,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(currentHouseholdRemindersProvider);

    return remindersAsync.when(
      data: (reminders) {
        if (reminders.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final reminder in reminders) ...[
              AppCard(
                onTap: () => _open(context, reminder),
                child: Row(
                  children: [
                    Icon(_iconFor(reminder.category), color: context.colors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reminder.title, style: Theme.of(context).textTheme.bodyMedium),
                          Text(reminder.message, style: Theme.of(context).textTheme.labelMedium),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, size: 18, color: context.colors.textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
          ],
        );
      },
      // Silent on loading/error -- these are low-stakes nudges, not worth
      // a spinner or error card competing for attention at the top of Home.
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}

/// Today's Schedule: real data, backed by
/// `households/{household}/events` filtered to today. Browsing anything
/// beyond today (or adding/editing an event) happens on the full Calendar
/// screen — this section only surfaces what's happening today.
class _TodaysScheduleSection extends ConsumerWidget {
  const _TodaysScheduleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(currentHouseholdTodaysEventsProvider);
    final members = ref.watch(currentHouseholdMembersProvider).valueOrNull ?? const <Member>[];
    final colorForMember = {
      for (final entry in members.asMap().entries) entry.value.id: AppColors.memberColor(entry.key),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeaderRow(
          title: "Today's Schedule",
          actionLabel: 'See all',
          onAction: () => context.go('/calendar'),
        ),
        const SizedBox(height: 8),
        eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return _EmptyStateCard(
                emoji: '📅',
                title: 'No events today',
                message: 'Your calendar is clear. Add an event for you or '
                    'someone in the family.',
                buttonLabel: 'Add event',
                onPressed: () => context.go('/calendar'),
              );
            }

            return AppCard(
              padding: EdgeInsets.zero,
              onTap: () => context.go('/calendar'),
              child: Column(
                children: [
                  for (final entry in events.asMap().entries) ...[
                    if (entry.key > 0) const Divider(height: 1),
                    _TodayEventTile(event: entry.value, colorForMember: colorForMember),
                  ],
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => _EmptyStateCard(
            emoji: '📅',
            title: "Couldn't load today's schedule",
            message: 'Pull to refresh or try again shortly.',
          ),
        ),
      ],
    );
  }
}

class _TodayEventTile extends StatelessWidget {
  const _TodayEventTile({required this.event, required this.colorForMember});

  final Event event;
  final Map<int, Color> colorForMember;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat.jm().format(event.startAt),
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.title,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (event.visibility == EventVisibility.private) ...[
            const SizedBox(width: 8),
            Icon(LucideIcons.lock, size: 14, color: context.colors.textSecondary),
          ],
          if (event.participants.isNotEmpty) ...[
            const SizedBox(width: 8),
            ParticipantAvatarStack(
              participants: event.participants,
              colorForMember: colorForMember,
              size: 18,
            ),
          ],
        ],
      ),
    );
  }
}

String _homeMealSlotLabel(MealSlot slot) => switch (slot) {
      MealSlot.breakfast => 'Breakfast',
      MealSlot.lunch => 'Lunch',
      MealSlot.dinner => 'Dinner',
    };

IconData _homeMealSlotIcon(MealSlot slot) => switch (slot) {
      MealSlot.breakfast => LucideIcons.coffee,
      MealSlot.lunch => LucideIcons.sandwich,
      MealSlot.dinner => LucideIcons.utensils,
    };

/// Today's Meals: real data, backed by `households/{household}/meal-plan-
/// items` filtered to today, same pattern as `_TodaysScheduleSection`.
/// Browsing/editing other days happens on the full Meals screen.
class _TodaysMealsSection extends ConsumerWidget {
  const _TodaysMealsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(currentHouseholdTodaysMealsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeaderRow(
          title: "Today's Meals",
          actionLabel: 'Request meal',
          onAction: () => context.go('/meals'),
        ),
        const SizedBox(height: 8),
        mealsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return _EmptyStateCard(
                emoji: '🍽️',
                title: 'No meals planned yet',
                message: "Your family hasn't planned today's meals yet.",
                buttonLabel: 'Plan meals',
                onPressed: () => context.go('/meals'),
              );
            }

            final bySlot = {for (final item in items) item.slot: item};

            return AppCard(
              padding: EdgeInsets.zero,
              onTap: () => context.go('/meals'),
              child: Column(
                children: [
                  for (final entry in MealSlot.values.asMap().entries) ...[
                    if (entry.key > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: context.colors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _homeMealSlotIcon(entry.value),
                              color: context.colors.primary,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _homeMealSlotLabel(entry.value).toUpperCase(),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: context.colors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.4,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  bySlot[entry.value]?.title ?? '—',
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: bySlot[entry.value] == null
                                            ? context.colors.textSecondary
                                            : null,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => _EmptyStateCard(
            emoji: '🍽️',
            title: "Couldn't load today's meals",
            message: 'Pull to refresh or try again shortly.',
          ),
        ),
      ],
    );
  }
}

/// Groceries: real data, backed by `households/{household}/grocery-items` —
/// shows a single summary row (count left to buy) rather than the full
/// list, which lives on the Groceries screen.
class _GroceriesSection extends ConsumerWidget {
  const _GroceriesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(currentHouseholdGroceryItemsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeaderRow(
          title: 'Groceries',
          actionLabel: 'View list',
          onAction: () => context.go('/groceries'),
        ),
        const SizedBox(height: 8),
        itemsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return _EmptyStateCard(
                emoji: '🛒',
                title: 'No groceries yet',
                message: 'Start your shared grocery list so the whole '
                    'family can chip in.',
                buttonLabel: 'Add items',
                onPressed: () => context.go('/groceries'),
              );
            }

            final unpurchased = items.where((i) => !i.isPurchased).toList();
            final categories = unpurchased.map((i) => i.category).whereType<String>().toSet().toList();
            const maxTags = 5;
            final shownCategories = categories.take(maxTags).toList();
            final remaining = categories.length - shownCategories.length;

            return AppCard(
              onTap: () => context.go('/groceries'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.shoppingBag, color: context.colors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          unpurchased.isEmpty
                              ? 'Everything is checked off'
                              : '${unpurchased.length} item${unpurchased.length == 1 ? '' : 's'} left to buy',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Icon(LucideIcons.chevronRight, size: 18, color: context.colors.textSecondary),
                    ],
                  ),
                  if (shownCategories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in shownCategories) _GroceryTag(label: category),
                        if (remaining > 0) _GroceryTag(label: '+$remaining more'),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => _EmptyStateCard(
            emoji: '🛒',
            title: "Couldn't load groceries",
            message: 'Pull to refresh or try again shortly.',
          ),
        ),
      ],
    );
  }
}

class _GroceryTag extends StatelessWidget {
  const _GroceryTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: context.colors.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Tasks due today or overdue, not yet completed — self-service completion
/// (like Groceries' purchase toggle), so this deliberately does NOT go
/// through the _AttentionItem/"Needs Your Attention" system, which exists
/// specifically for requester-vs-approver flows.
class _TasksSection extends ConsumerWidget {
  const _TasksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(currentHouseholdTodaysTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeaderRow(
          title: 'Tasks',
          actionLabel: 'View all',
          onAction: () => context.push('/tasks'),
        ),
        const SizedBox(height: 8),
        tasksAsync.when(
          data: (tasks) {
            if (tasks.isEmpty) {
              return _EmptyStateCard(
                emoji: '✅',
                title: 'No tasks today',
                message: 'Assign chores and one-off tasks so everyone '
                    'knows what needs doing.',
                buttonLabel: 'Add a task',
                onPressed: () => context.push('/tasks'),
              );
            }

            final overdueCount = tasks.where((t) => t.isOverdue).length;

            return AppCard(
              onTap: () => context.push('/tasks'),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.checkCircle,
                    color: overdueCount > 0 ? context.colors.error : context.colors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      overdueCount > 0
                          ? '$overdueCount overdue, ${tasks.length} total left today'
                          : '${tasks.length} task${tasks.length == 1 ? '' : 's'} left today',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, size: 18, color: context.colors.textSecondary),
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => _EmptyStateCard(
            emoji: '✅',
            title: "Couldn't load tasks",
            message: 'Pull to refresh or try again shortly.',
          ),
        ),
      ],
    );
  }
}

class _TripsSection extends ConsumerWidget {
  const _TripsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(currentHouseholdUpcomingTripProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeaderRow(
          title: 'Upcoming Trip',
          actionLabel: 'View all',
          onAction: () => context.push('/trips'),
        ),
        const SizedBox(height: 8),
        tripAsync.when(
          data: (trip) {
            if (trip == null) {
              return _EmptyStateCard(
                emoji: '✈️',
                title: 'No upcoming trips',
                message: 'Plan a family trip — camping, beach, or even a '
                    "staycation — and keep everyone's itinerary in one place.",
                buttonLabel: 'Plan a trip',
                onPressed: () => context.push('/trips'),
              );
            }

            final dateLabel = [
              DateFormat('MMM d').format(trip.startAt),
              if (trip.endAt != null) '–${DateFormat('d').format(trip.endAt!)}',
            ].join('');

            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: context.colors.primarySoft,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'UPCOMING TRIP',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: context.colors.primary,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                trip.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [dateLabel, if (trip.destination != null) trip.destination!]
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: context.colors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (trip.daysUntil != null && trip.daysUntil! > 0) ...[
                          const SizedBox(width: 12),
                          _DaysToGoBadge(days: trip.daysUntil!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => _EmptyStateCard(
            emoji: '✈️',
            title: "Couldn't load trips",
            message: 'Pull to refresh or try again shortly.',
          ),
        ),
      ],
    );
  }
}

/// Solid-teal "N days to go" pill shown on the Upcoming Trip banner.
class _DaysToGoBadge extends StatelessWidget {
  const _DaysToGoBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: context.colors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$days',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.colors.primaryForeground,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            'days to go',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.colors.primaryForeground,
                  height: 1.1,
                ),
          ),
        ],
      ),
    );
  }
}

/// Needs Your Attention: permission requests AND meal requests the viewer
/// can act on right now, each its own single-row card with inline Approve/
/// Review/Decline actions — not grouped inside one card whose whole area
/// used to navigate to the (permission-only) Requests screen regardless of
/// which item, or what type, was actually tapped. A resolved request never
/// shows here, even unacknowledged — see `_resolvedAttentionItems`, surfaced
/// only in the bell sheet. A capped-at-3 preview; "See all" (added below
/// once there are more) would go to the full list.
class _PendingRequestsSection extends ConsumerWidget {
  const _PendingRequestsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(currentHouseholdRequestsProvider);
    final mealRequestsAsync = ref.watch(currentHouseholdMealRequestsProvider);
    final household = ref.watch(currentHouseholdProvider);
    final myMemberId = ref.watch(authControllerProvider).user?.member?.id;
    final canManage = household?.myRole == 'owner' || household?.myRole == 'adult';

    if (requestsAsync.isLoading || mealRequestsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (requestsAsync.hasError || mealRequestsAsync.hasError) {
      return const _EmptyStateCard(
        emoji: '✅',
        title: "Couldn't load requests",
        message: 'Pull to refresh or try again shortly.',
      );
    }

    final attention = _actionableAttentionItems(
      permissionRequests: requestsAsync.valueOrNull ?? const [],
      mealRequests: mealRequestsAsync.valueOrNull ?? const [],
      myMemberId: myMemberId,
      canManagePermissions: canManage,
      canManageMeals: _canManageMealsFor(household, myMemberId),
    );

    if (attention.isEmpty) {
      return const _EmptyStateCard(
        emoji: '✅',
        title: "You're all caught up",
        message: 'Permission and meal requests from the family will show '
            'up here for you to review.',
      );
    }

    return Column(
      children: [
        for (final item in attention.take(3)) ...[
          _AttentionItemCard(item: item),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// A single "needs your attention" row: an icon avatar, the description
/// sentence, and either a three-button Approve/Review/Decline row (when
/// the viewer can act) or a single Review button (the viewer's own
/// request, surfaced just so they notice the outcome).
class _AttentionItemCard extends ConsumerWidget {
  const _AttentionItemCard({required this.item});

  final _AttentionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.iconBackground.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 16, color: item.iconBackground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(item.description, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (item.canAct) ...[
                Expanded(
                  child: _AttentionPillButton(
                    label: 'Approve',
                    background: context.colors.primary,
                    foreground: context.colors.primaryForeground,
                    onPressed: () => item.onApprove!(context, ref),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _AttentionPillButton(
                  label: 'Review',
                  background: context.colors.primary.withValues(alpha: 0.12),
                  foreground: context.colors.primary,
                  onPressed: () => item.onReview(context, ref),
                ),
              ),
              if (item.canAct) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _AttentionPillButton(
                    label: 'Decline',
                    background: context.colors.error.withValues(alpha: 0.12),
                    foreground: context.colors.error,
                    onPressed: () => item.onDecline!(context, ref),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AttentionPillButton extends StatelessWidget {
  const _AttentionPillButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1, softWrap: false),
      ),
    );
  }
}

/// The header bell's target — a personal, scoped view of what needs this
/// viewer's attention (mirrors `_actionableAttentionItems`/
/// `_PendingRequestsSection` above, now covering meal requests too), as
/// opposed to the "Permissions" tile which opens the full household-wide
/// Requests management screen regardless of viewer. Pops with the string
/// 'view-all' if the viewer wants that fuller screen instead — the caller
/// (the bell's onPressed) pushes `/requests` for it, the same
/// pop-then-caller-acts pattern `_HouseholdSwitcherSheet` uses.
///
/// Opening this sheet clears the bell badge for *everything* it shows,
/// actionable or not (see `_onAttentionItemsVisible`) — the badge is a "new
/// since last viewed" counter, not a "work remaining" counter, so a pending
/// request the viewer hasn't acted on yet still stops counting once seen
/// here (it still shows in "Needs Your Attention" and this sheet's
/// actionable section regardless, since those are about what still needs
/// doing). Also shows a "Recently resolved" section for the viewer's own
/// requests that were just approved/declined, which are additionally
/// acknowledged server-side as soon as this sheet renders them, rather than
/// requiring a tap into each one's detail sheet.
class _NotificationsSheet extends ConsumerStatefulWidget {
  const _NotificationsSheet();

  @override
  ConsumerState<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends ConsumerState<_NotificationsSheet> {
  final Set<String> _acknowledging = {};

  /// Called on every build with whatever's currently visible: marks all of
  /// it "seen" (clearing the badge for it, actionable or not) and kicks off
  /// the acknowledge API call for the resolved ones specifically (so they
  /// stop needing the requester's attention server-side, not just locally).
  void _onAttentionItemsVisible(List<_AttentionItem> actionable, List<_AttentionItem> resolved) {
    final visibleIds = {...actionable.map((i) => i.id), ...resolved.map((i) => i.id)};
    final seenIds = ref.read(_seenAttentionItemIdsProvider);
    final newlySeen = visibleIds.difference(seenIds);

    final toAcknowledge = resolved.where((item) => !_acknowledging.contains(item.id)).toList();
    for (final item in toAcknowledge) {
      _acknowledging.add(item.id);
    }

    if (newlySeen.isEmpty && toAcknowledge.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (newlySeen.isNotEmpty) {
        ref.read(_seenAttentionItemIdsProvider.notifier).update((state) => {...state, ...newlySeen});
      }
      for (final item in toAcknowledge) {
        item.onAcknowledge?.call(ref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(currentHouseholdRequestsProvider);
    final mealRequestsAsync = ref.watch(currentHouseholdMealRequestsProvider);
    final household = ref.watch(currentHouseholdProvider);
    final myMemberId = ref.watch(authControllerProvider).user?.member?.id;
    final canManage = household?.myRole == 'owner' || household?.myRole == 'adult';
    final canManageMeals = _canManageMealsFor(household, myMemberId);

    final isLoading = requestsAsync.isLoading || mealRequestsAsync.isLoading;
    final hasError = requestsAsync.hasError || mealRequestsAsync.hasError;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (hasError)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              "Couldn't load notifications.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          Builder(
            builder: (context) {
              final permissionRequests = requestsAsync.valueOrNull ?? const [];
              final mealRequests = mealRequestsAsync.valueOrNull ?? const [];

              final actionable = _actionableAttentionItems(
                permissionRequests: permissionRequests,
                mealRequests: mealRequests,
                myMemberId: myMemberId,
                canManagePermissions: canManage,
                canManageMeals: canManageMeals,
              );
              final resolved = _resolvedAttentionItems(
                permissionRequests: permissionRequests,
                mealRequests: mealRequests,
              );

              _onAttentionItemsVisible(actionable, resolved);

              if (actionable.isEmpty && resolved.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    "You're all caught up.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              return Column(
                children: [
                  for (final item in actionable) ...[
                    _AttentionItemCard(item: item),
                    const SizedBox(height: 10),
                  ],
                  if (resolved.isNotEmpty) ...[
                    if (actionable.isNotEmpty) const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Recently resolved',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: context.colors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final item in resolved) ...[
                      _AttentionItemCard(item: item),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              );
            },
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop('view-all'),
            child: const Text('View all requests'),
          ),
        ),
      ],
    );
  }
}

/// Family Notes: real data (unlike the other empty-state Home sections),
/// backed by `households/{household}/notes`. Anyone in the household can
/// leave a note; the author or an Owner/Adult can remove one.
class _FamilyNotesSection extends ConsumerWidget {
  const _FamilyNotesSection();

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    final added = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddNoteSheet(householdId: household.id),
    );

    if (added == true) ref.invalidate(currentHouseholdNotesProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, FamilyNote note) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    try {
      await ref.read(familyNoteRepositoryProvider).delete(
            householdId: household.id,
            noteId: note.id,
          );
      ref.invalidate(currentHouseholdNotesProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(currentHouseholdNotesProvider);
    final household = ref.watch(currentHouseholdProvider);
    final myMemberId = ref.watch(authControllerProvider).user?.member?.id;
    final canModerate = household?.myRole == 'owner' || household?.myRole == 'adult';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeaderRow(
          title: 'Family Notes',
          actionLabel: '+ Add note',
          onAction: () => _openAddSheet(context, ref),
        ),
        const SizedBox(height: 8),
        notesAsync.when(
          data: (notes) {
            if (notes.isEmpty) {
              return _EmptyStateCard(
                emoji: '📝',
                title: 'No notes yet',
                message: 'Leave a quick message for your family — '
                    'reminders, encouragement, or just a hello.',
                buttonLabel: 'Leave a note',
                onPressed: () => _openAddSheet(context, ref),
              );
            }

            return SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: notes.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final canDelete = canModerate || note.authorMemberId == myMemberId;
                  final noteColors = _kNoteColors(context);
                  final color = noteColors[index % noteColors.length];

                  return Container(
                    width: 180,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            note.content,
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note.authorName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _timeLeftLabel(note.expiresAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (canDelete)
                              InkWell(
                                onTap: () => _delete(context, ref, note),
                                customBorder: const CircleBorder(),
                                // Padding brings the tap target up to the
                                // 44x44 minimum without growing the visible
                                // icon — the Column above still has enough
                                // slack for this row to grow into.
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Icon(
                                    LucideIcons.x,
                                    size: 16,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => _EmptyStateCard(
            emoji: '📝',
            title: "Couldn't load notes",
            message: error is ApiException
                ? error.message
                : 'Something went wrong. Please try again.',
            buttonLabel: 'Retry',
            onPressed: () => ref.invalidate(currentHouseholdNotesProvider),
          ),
        ),
      ],
    );
  }
}

class _AddNoteSheet extends ConsumerStatefulWidget {
  const _AddNoteSheet({required this.householdId});

  final int householdId;

  @override
  ConsumerState<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<_AddNoteSheet> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(familyNoteRepositoryProvider).create(
            householdId: widget.householdId,
            content: content,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Leave a family note', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Visible to the household for 24 hours.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        AppTextField(
          label: 'Message',
          controller: _controller,
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Post note',
          isLoading: _isLoading,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Announcements: like Family Notes, but longer-lived (no expiration) and
/// restricted to an Owner/Adult posting — a household bulletin rather than
/// a free-for-all sticky note. Backed by
/// `households/{household}/announcements`.
class _AnnouncementsSection extends ConsumerWidget {
  const _AnnouncementsSection();

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    final added = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddAnnouncementSheet(householdId: household.id),
    );

    if (added == true) ref.invalidate(currentHouseholdAnnouncementsProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Announcement announcement) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    try {
      await ref.read(announcementRepositoryProvider).delete(
            householdId: household.id,
            announcementId: announcement.id,
          );
      ref.invalidate(currentHouseholdAnnouncementsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(currentHouseholdAnnouncementsProvider);
    final household = ref.watch(currentHouseholdProvider);
    final myMemberId = ref.watch(authControllerProvider).user?.member?.id;
    final canModerate = household?.myRole == 'owner' || household?.myRole == 'adult';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canModerate)
          _SectionHeaderRow(
            title: 'Announcements',
            actionLabel: '+ Post',
            onAction: () => _openAddSheet(context, ref),
          )
        else
          Text('Announcements', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        announcementsAsync.when(
          data: (announcements) {
            if (announcements.isEmpty) {
              return _EmptyStateCard(
                emoji: '📣',
                title: 'No announcements yet',
                message: canModerate
                    ? 'Share something the whole household should know.'
                    : "Household announcements from an adult will show up here.",
                buttonLabel: canModerate ? 'Post announcement' : null,
                onPressed: canModerate ? () => _openAddSheet(context, ref) : null,
              );
            }

            return Column(
              children: [
                for (final announcement in announcements) ...[
                  _AnnouncementCard(
                    announcement: announcement,
                    canDelete: canModerate || announcement.authorMemberId == myMemberId,
                    onDelete: () => _delete(context, ref, announcement),
                  ),
                  if (announcement != announcements.last) const SizedBox(height: 10),
                ],
              ],
            );
          },
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => _EmptyStateCard(
            emoji: '📣',
            title: "Couldn't load announcements",
            message: error is ApiException
                ? error.message
                : 'Something went wrong. Please try again.',
            buttonLabel: 'Retry',
            onPressed: () => ref.invalidate(currentHouseholdAnnouncementsProvider),
          ),
        ),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.canDelete,
    required this.onDelete,
  });

  final Announcement announcement;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.megaphone, color: context.colors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(announcement.content, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(
                  '${announcement.authorName} · ${_announcementTimeLabel(announcement.createdAt)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
          if (canDelete)
            InkWell(
              onTap: onDelete,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Icon(LucideIcons.x, size: 16, color: context.colors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddAnnouncementSheet extends ConsumerStatefulWidget {
  const _AddAnnouncementSheet({required this.householdId});

  final int householdId;

  @override
  ConsumerState<_AddAnnouncementSheet> createState() => _AddAnnouncementSheetState();
}

class _AddAnnouncementSheetState extends ConsumerState<_AddAnnouncementSheet> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(announcementRepositoryProvider).create(
            householdId: widget.householdId,
            content: content,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Post an announcement', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          "Visible to the whole household until you remove it.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        AppTextField(
          label: 'Announcement',
          controller: _controller,
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Post announcement',
          isLoading: _isLoading,
          onPressed: _submit,
        ),
      ],
    );
  }
}

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
            fallbackIndex: i,
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
              border: Border.all(color: context.colors.border, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.plus, color: context.colors.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  'Create or join a household',
                  style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop('logout'),
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
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
    required this.fallbackIndex,
    required this.selected,
    required this.onTap,
  });

  final Household household;
  final int fallbackIndex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = household.color != null
        ? householdColorFromHex(context, household.color)
        : AppColors.memberColor(fallbackIndex);
    final emoji = household.emoji ?? kHouseholdEmojis[fallbackIndex % kHouseholdEmojis.length];
    final count = household.memberCount;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? context.colors.primary.withValues(alpha: 0.08) : context.colors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? context.colors.primary.withValues(alpha: 0.4) : context.colors.border,
          ),
        ),
        child: AppListRow(
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          title: household.name,
          subtitle: count != null
              ? Text(
                  '$count ${count == 1 ? 'member' : 'members'}',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : null,
          trailing: selected
              ? Icon(LucideIcons.checkCircle, color: context.colors.primary)
              : const SizedBox(width: 24, height: 24),
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
                    MemberAvatar(
                      name: member.name,
                      colorIndex: index,
                      avatarUrl: member.avatarUrl,
                      size: 56,
                    ),
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
                      ?.copyWith(color: context.colors.textPrimary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Map is Phase 8 work that hasn't started — it opens the shared
/// ComingSoonScreen rather than faking functionality. Chores/Tasks (Phase
/// 6), Permissions, and Trips (Phase 7) are real: Chores opens the Tasks
/// screen, Permissions opens the Requests screen (Phase 4), Trips opens
/// the Trips screen.
class _MoreRow extends StatelessWidget {
  const _MoreRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MoreTile(
            icon: LucideIcons.checkCircle,
            color: context.colors.primary,
            label: 'Chores',
            onTap: () => context.push('/tasks'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MoreTile(
            icon: LucideIcons.mapPin,
            color: context.colors.error,
            label: 'Map',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ComingSoonScreen(
                  title: 'Map',
                  icon: LucideIcons.mapPin,
                  message: "Seeing your family's location is on its way.",
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MoreTile(
            icon: LucideIcons.shield,
            color: AppColors.skyBlue,
            label: 'Permissions',
            onTap: () => context.push('/requests'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MoreTile(
            icon: LucideIcons.plane,
            color: AppColors.lavender,
            label: 'Trips',
            onTap: () => context.push('/trips'),
          ),
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
