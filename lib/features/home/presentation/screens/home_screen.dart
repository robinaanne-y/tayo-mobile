import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_list_row.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/screens/coming_soon_screen.dart';
import '../../../announcements/domain/announcement.dart';
import '../../../announcements/presentation/announcement_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../../family_notes/domain/family_note.dart';
import '../../../family_notes/presentation/family_note_providers.dart';
import '../../../households/domain/household.dart';
import '../../../households/presentation/household_visuals.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../../members/presentation/providers/member_providers.dart';

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
    final householdColor = householdColorFromHex(context, household?.color);
    final householdEmoji = household?.emoji ?? kHouseholdEmojis.first;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: context.colors.surface,
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
                    icon: const Icon(LucideIcons.bell),
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
                        color: householdColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(householdEmoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            household?.name ?? 'Household',
                            style: TextStyle(
                              color: householdColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
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
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _SectionHeaderRow(
                    title: "Today's Schedule",
                    actionLabel: 'See all',
                    onAction: () => context.go('/calendar'),
                  ),
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
                  Text('Needs Your Attention', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const _EmptyStateCard(
                    emoji: '✅',
                    title: "You're all caught up",
                    message: 'Permission requests from the family will show '
                        'up here for you to review.',
                  ),
                  const SizedBox(height: 24),
                  const _FamilyNotesSection(),
                  const SizedBox(height: 24),
                  const _AnnouncementsSection(),
                  const SizedBox(height: 24),
                  _SectionHeaderRow(
                    title: "Today's Meals",
                    actionLabel: 'Request meal',
                    onAction: () => context.go('/meals'),
                  ),
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
                  _SectionHeaderRow(
                    title: 'Groceries',
                    actionLabel: 'View list',
                    onAction: () => context.go('/groceries'),
                  ),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
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
                                child: Icon(
                                  LucideIcons.x,
                                  size: 16,
                                  color: context.colors.textSecondary,
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
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
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

/// Chores, Map and Permissions are Phase 6/8/4 work that hasn't started —
/// each opens the shared ComingSoonScreen rather than faking functionality.
/// Profile is real: it opens the profile edit screen directly, since
/// there's no dedicated settings/profile tab yet to house it.
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ComingSoonScreen(
                  title: 'Chores',
                  icon: LucideIcons.checkCircle,
                  message: 'Assigning and tracking chores is on its way.',
                ),
              ),
            ),
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ComingSoonScreen(
                  title: 'Permissions',
                  icon: LucideIcons.shield,
                  message: 'Requesting and approving permissions is on its way.',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MoreTile(
            icon: LucideIcons.user,
            color: AppColors.lavender,
            label: 'Profile',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
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
