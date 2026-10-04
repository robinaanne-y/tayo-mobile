import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_list_row.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../../shared/widgets/participant_avatar_stack.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../households/domain/household.dart';
import '../../../households/presentation/household_visuals.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../../members/domain/member.dart';
import '../../../members/presentation/providers/member_providers.dart';
import '../../../trips/presentation/screens/trip_detail_screen.dart';
import '../../domain/event.dart';
import '../providers/event_providers.dart';

enum _CalendarViewMode { month, week, day }

String _visibilityLabel(EventVisibility visibility) => switch (visibility) {
      EventVisibility.private => 'Private',
      EventVisibility.household => 'Household',
      EventVisibility.selectedHouseholds => 'Selected households',
      EventVisibility.allMemberHouseholds => 'All my households',
    };

String _recurrenceUnitLabel(RecurrenceFrequency frequency, int interval) {
  final plural = interval != 1;
  return switch (frequency) {
    RecurrenceFrequency.daily => plural ? 'days' : 'day',
    RecurrenceFrequency.weekly => plural ? 'weeks' : 'week',
    RecurrenceFrequency.monthly => plural ? 'months' : 'month',
  };
}

const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// The member an event is displayed as belonging to, for color-coding and
/// labeling — the first tagged participant when there is one, since the
/// event is "about" who it's for, not who happened to create it; falls
/// back to the creator when nobody's been tagged.
int _primaryMemberId(Event event) =>
    event.participants.isNotEmpty ? event.participants.first.id : event.creatorMemberId;

/// Describes who an event is for: the creator when nobody's tagged, "All"
/// when every household member is a participant, every name when there are
/// only a couple, or the first two plus a "+N more" count once the list
/// gets long enough that spelling it out would crowd the card.
String _participantsLabel(Event event, int householdMemberCount) {
  final participants = event.participants;
  if (participants.isEmpty) return event.creatorName;
  if (householdMemberCount > 0 && participants.length == householdMemberCount) {
    return 'All';
  }
  if (participants.length <= 3) {
    return participants.map((p) => p.name).join(', ');
  }
  final shown = participants.take(2).map((p) => p.name).join(', ');
  return '$shown +${participants.length - 2} more';
}

/// Whether [event] should be visible under the Calendar screen's member
/// filter — an empty [filterMemberIds] means "no filter, show everything".
/// An event matches when any of its tagged participants is in the filter,
/// or (for an event nobody's been tagged on) when its creator is.
bool _eventMatchesFilter(Event event, Set<int> filterMemberIds) {
  if (filterMemberIds.isEmpty) return true;
  if (event.participants.isEmpty) return filterMemberIds.contains(event.creatorMemberId);
  return event.participants.any((p) => filterMemberIds.contains(p.id));
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  _CalendarViewMode _viewMode = _CalendarViewMode.month;
  final Set<int> _filterMemberIds = {};

  void _toggleMemberFilter(int memberId) {
    setState(() {
      if (!_filterMemberIds.remove(memberId)) {
        _filterMemberIds.add(memberId);
      }
    });
  }

  ({DateTime start, DateTime end}) get _visibleRange {
    switch (_viewMode) {
      case _CalendarViewMode.month:
        final start = DateTime(_focusedDay.year, _focusedDay.month, 1);
        final end =
            DateTime(_focusedDay.year, _focusedDay.month + 1, 1).subtract(const Duration(seconds: 1));
        return (start: start, end: end);
      case _CalendarViewMode.week:
        final daysSinceSunday = _selectedDay.weekday % 7;
        final weekStart = _selectedDay.subtract(Duration(days: daysSinceSunday));
        final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        final end = start.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
        return (start: start, end: end);
      case _CalendarViewMode.day:
        final start = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
        final end = start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        return (start: start, end: end);
    }
  }

  void _refresh() {
    ref.invalidate(currentHouseholdEventsInRangeProvider(_visibleRange));
    ref.invalidate(currentHouseholdTodaysEventsProvider);
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      _focusedDay = day;
    });
  }

  Future<void> _openAddEditSheet({Event? existing}) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    final saved = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddEditEventSheet(
        householdId: household.id,
        initialDate: _selectedDay,
        existing: existing,
      ),
    );

    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final range = _visibleRange;
    final eventsAsync = ref.watch(currentHouseholdEventsInRangeProvider(range));
    final members = ref.watch(currentHouseholdMembersProvider).valueOrNull ?? const <Member>[];
    final colorForMember = {
      for (final entry in members.asMap().entries) entry.value.id: AppColors.memberColor(entry.key),
    };

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddEditSheet(),
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.primaryForeground,
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _CalendarHeader(
              title: DateFormat('MMM yyyy').format(_selectedDay),
              viewMode: _viewMode,
              onViewModeChanged: (mode) => setState(() => _viewMode = mode),
              members: members,
              colorForMember: colorForMember,
              filterMemberIds: _filterMemberIds,
              onMemberToggled: _toggleMemberFilter,
            ),
            Expanded(
              child: eventsAsync.when(
                data: (events) {
                  final visibleEvents =
                      events.where((e) => _eventMatchesFilter(e, _filterMemberIds)).toList();
                  final eventsByDay = <DateTime, List<Event>>{};
                  for (final event in visibleEvents) {
                    final day = DateTime(event.startAt.year, event.startAt.month, event.startAt.day);
                    eventsByDay.putIfAbsent(day, () => []).add(event);
                  }

                  final selectedKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
                  final selectedEvents = eventsByDay[selectedKey] ?? const <Event>[];

                  return Column(
                    children: [
                      if (_viewMode == _CalendarViewMode.month)
                        TableCalendar<Event>(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2035, 12, 31),
                          focusedDay: _focusedDay,
                          calendarFormat: CalendarFormat.month,
                          headerVisible: false,
                          // The package's default daysOfWeekHeight (16px)
                          // assumes its own small default text style; ours
                          // (inherited from the ambient TextTheme) is taller
                          // and was getting clipped, so both are set
                          // explicitly together.
                          daysOfWeekHeight: 24,
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                            weekendStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                          ),
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          eventLoader: (day) {
                            final key = DateTime(day.year, day.month, day.day);
                            return eventsByDay[key] ?? const <Event>[];
                          },
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, day, dayEvents) {
                              if (dayEvents.isEmpty) return null;
                              return Positioned(
                                bottom: 2,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final event in dayEvents.take(3))
                                      Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(horizontal: 1),
                                        decoration: BoxDecoration(
                                          color: colorForMember[_primaryMemberId(event)] ??
                                              context.colors.border,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            setState(() => _focusedDay = focusedDay);
                          },
                        )
                      else if (_viewMode == _CalendarViewMode.week)
                        _WeekStrip(
                          weekStart: range.start,
                          selectedDay: _selectedDay,
                          eventsByDay: eventsByDay,
                          colorForMember: colorForMember,
                          onDaySelected: _selectDay,
                        ),
                      const Divider(height: 1),
                      _DateSubHeader(
                        selectedDay: _selectedDay,
                        showDayNav: _viewMode == _CalendarViewMode.day,
                        onPreviousDay: () =>
                            _selectDay(_selectedDay.subtract(const Duration(days: 1))),
                        onNextDay: () => _selectDay(_selectedDay.add(const Duration(days: 1))),
                      ),
                      Expanded(
                        child: selectedEvents.isEmpty
                            ? Center(
                                child: Text(
                                  'No events on this day',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                itemCount: selectedEvents.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: AppSpacing.space12),
                                itemBuilder: (context, index) {
                                  final event = selectedEvents[index];
                                  return _EventListTile(
                                    event: event,
                                    colorForMember: colorForMember,
                                    householdMemberCount: members.length,
                                    onTap: event.isTripDerived
                                        ? () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => TripDetailScreen(tripId: event.tripId!),
                                              ),
                                            )
                                        : () => _openAddEditSheet(existing: event),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text(
                    "Couldn't load the calendar. Please try again.",
                    style: Theme.of(context).textTheme.bodySmall,
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

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.title,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.members,
    required this.colorForMember,
    required this.filterMemberIds,
    required this.onMemberToggled,
  });

  final String title;
  final _CalendarViewMode viewMode;
  final ValueChanged<_CalendarViewMode> onViewModeChanged;
  final List<Member> members;
  final Map<int, Color> colorForMember;
  final Set<int> filterMemberIds;
  final ValueChanged<int> onMemberToggled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 8),
              Theme(
                data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
                child: SegmentedButton<_CalendarViewMode>(
                  segments: const [
                    ButtonSegment(value: _CalendarViewMode.month, label: Text('Month')),
                    ButtonSegment(value: _CalendarViewMode.week, label: Text('Week')),
                    ButtonSegment(value: _CalendarViewMode.day, label: Text('Day')),
                  ],
                  selected: {viewMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => onViewModeChanged(selection.first),
                ),
              ),
            ],
          ),
          if (members.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final member in members)
                  _MemberFilterChip(
                    member: member,
                    color: colorForMember[member.id] ?? context.colors.border,
                    isFilterActive: filterMemberIds.isNotEmpty,
                    isSelected: filterMemberIds.contains(member.id),
                    onTap: () => onMemberToggled(member.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A tappable legend entry that doubles as a member filter: tapping it
/// toggles whether the Calendar screen narrows down to just that member's
/// events. Undimmed and unhighlighted when no filter is active (today's
/// plain legend look); once any member is selected, the rest dim so the
/// active filter is obvious.
class _MemberFilterChip extends StatelessWidget {
  const _MemberFilterChip({
    required this.member,
    required this.color,
    required this.isFilterActive,
    required this.isSelected,
    required this.onTap,
  });

  final Member member;
  final Color color;
  final bool isFilterActive;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: !isFilterActive || isSelected ? 1 : 0.4,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(member.name, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.weekStart,
    required this.selectedDay,
    required this.eventsByDay,
    required this.colorForMember,
    required this.onDaySelected,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final Map<DateTime, List<Event>> eventsByDay;
  final Map<int, Color> colorForMember;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: List.generate(7, (i) {
          final day = weekStart.add(Duration(days: i));
          final key = DateTime(day.year, day.month, day.day);
          final isSelected = isSameDay(day, selectedDay);
          final dayEvents = eventsByDay[key] ?? const <Event>[];

          return Expanded(
            child: GestureDetector(
              onTap: () => onDaySelected(day),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? context.colors.primary : context.colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? context.colors.primary : context.colors.border,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat.E().format(day).substring(0, 3),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: isSelected
                                ? context.colors.primaryForeground
                                : context.colors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color:
                                isSelected ? context.colors.primaryForeground : context.colors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final event in dayEvents.take(2))
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.colors.primaryForeground
                                    : (colorForMember[_primaryMemberId(event)] ?? context.colors.border),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DateSubHeader extends StatelessWidget {
  const _DateSubHeader({
    required this.selectedDay,
    required this.showDayNav,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  final DateTime selectedDay;
  final bool showDayNav;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          if (showDayNav)
            IconButton(
              icon: const Icon(LucideIcons.chevronLeft),
              tooltip: 'Previous day',
              onPressed: onPreviousDay,
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              DateFormat('MMMM d').format(selectedDay),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (showDayNav)
            IconButton(
              icon: const Icon(LucideIcons.chevronRight),
              tooltip: 'Next day',
              onPressed: onNextDay,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _EventListTile extends StatelessWidget {
  const _EventListTile({
    required this.event,
    required this.colorForMember,
    required this.householdMemberCount,
    required this.onTap,
  });

  final Event event;
  final Map<int, Color> colorForMember;
  final int householdMemberCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ownerColor = colorForMember[_primaryMemberId(event)] ?? context.colors.border;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: AppListRow(
          leading: event.isTripDerived
              ? Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.lavender.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.plane, size: 16, color: AppColors.lavender),
                )
              : Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ownerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
          title: event.title,
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${DateFormat.jm().format(event.startAt)} · '
                '${_participantsLabel(event, householdMemberCount)}'
                '${event.visibility == EventVisibility.private ? ' · Private' : ''}'
                '${event.isTripDerived ? ' · Trip' : ''}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (event.location != null && event.location!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.mapPin, size: 12, color: context.colors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        event.location!,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ],
              if (event.isRecurring) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.repeat, size: 12, color: context.colors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        event.recurrenceSummary ?? 'Repeats',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          trailing: event.participants.isEmpty
              ? Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: ownerColor, shape: BoxShape.circle),
                )
              : ParticipantAvatarStack(
                  participants: event.participants,
                  colorForMember: colorForMember,
                ),
        ),
      ),
    );
  }
}

class _AddEditEventSheet extends ConsumerStatefulWidget {
  const _AddEditEventSheet({
    required this.householdId,
    required this.initialDate,
    this.existing,
  });

  final int householdId;
  final DateTime initialDate;
  final Event? existing;

  @override
  ConsumerState<_AddEditEventSheet> createState() => _AddEditEventSheetState();
}

enum _RecurrenceEndMode { onDate, afterCount }

class _AddEditEventSheetState extends ConsumerState<_AddEditEventSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _recurrenceIntervalController = TextEditingController(text: '1');
  final _recurrenceOccurrenceCountController = TextEditingController(text: '4');
  late DateTime _startAt;
  late DateTime _endAt;
  late EventVisibility _visibility;
  late Set<int> _selectedParticipantIds;
  late Set<int> _selectedHouseholdIds;
  bool _isLoading = false;
  String? _errorMessage;

  // Recurrence is create-only: the pattern is immutable once the event
  // exists, so none of this is read from `widget.existing`.
  RecurrenceFrequency? _recurrenceFrequency;
  Set<int> _recurrenceByDay = {};
  // Defaults to afterCount (paired with the occurrence-count field's own
  // default of 4) rather than onDate, since onDate has no valid value
  // until the date picker is actually completed -- defaulting to it left
  // "Add event" reachable with an end mode selected but no date behind
  // it, if the user never opened the picker at all.
  _RecurrenceEndMode _recurrenceEndMode = _RecurrenceEndMode.afterCount;
  DateTime? _recurrenceEndsAt;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _selectedParticipantIds = existing?.participants.map((p) => p.id).toSet() ?? {};
    _selectedHouseholdIds = existing?.sharedHouseholds.map((h) => h.id).toSet() ?? {};
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description ?? '';
      _locationController.text = existing.location ?? '';
      _startAt = existing.startAt;
      _endAt = existing.endAt;
      _visibility = existing.visibility;
    } else {
      final base = DateTime(
        widget.initialDate.year,
        widget.initialDate.month,
        widget.initialDate.day,
        9,
      );
      _startAt = base;
      _endAt = base.add(const Duration(hours: 1));
      _visibility = EventVisibility.household;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _recurrenceIntervalController.dispose();
    _recurrenceOccurrenceCountController.dispose();
    super.dispose();
  }

  /// Shown before saving/deleting an occurrence that belongs to a
  /// recurring series, since the pattern itself can't be edited — only how
  /// far the change propagates. Returns 'this', 'following', or null if
  /// the user backed out.
  Future<String?> _pickEditScope(String actionLabel) {
    return showAppBottomSheet<String>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$actionLabel this event', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'This is part of a repeating series.',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('This event'),
            onTap: () => Navigator.of(context).pop('this'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('This and following events'),
            onTap: () => Navigator.of(context).pop('following'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _startAt : _endAt;

    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;

    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startAt = picked;
        if (_endAt.isBefore(_startAt)) {
          _endAt = _startAt.add(const Duration(hours: 1));
        }
      } else {
        _endAt = picked;
      }
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    if (_endAt.isBefore(_startAt)) {
      setState(() => _errorMessage = 'End time must be after the start time.');
      return;
    }

    int? recurrenceOccurrenceCount;
    if (_recurrenceFrequency != null) {
      if (_recurrenceEndMode == _RecurrenceEndMode.onDate) {
        if (_recurrenceEndsAt == null) {
          setState(() => _errorMessage = 'Choose an end date for the recurrence.');
          return;
        }
      } else {
        recurrenceOccurrenceCount = int.tryParse(_recurrenceOccurrenceCountController.text);
        if (recurrenceOccurrenceCount == null || recurrenceOccurrenceCount < 1) {
          setState(() => _errorMessage = 'Enter how many times the event should occur.');
          return;
        }
      }
    }

    final existing = widget.existing;
    var editScope = 'this';
    if (existing != null && existing.isRecurring) {
      final scope = await _pickEditScope('Save changes to');
      if (scope == null) return;
      editScope = scope;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();

    try {
      final repository = ref.read(eventRepositoryProvider);
      if (existing != null) {
        await repository.update(
          householdId: widget.householdId,
          eventId: int.parse(existing.id),
          title: title,
          description: description.isEmpty ? null : description,
          location: location.isEmpty ? null : location,
          startAt: _startAt,
          endAt: _endAt,
          visibility: _visibility,
          participantMemberIds: _selectedParticipantIds.toList(),
          sharedHouseholdIds: _selectedHouseholdIds.toList(),
          editScope: editScope,
        );
      } else {
        final interval = int.tryParse(_recurrenceIntervalController.text) ?? 1;
        await repository.create(
          householdId: widget.householdId,
          title: title,
          description: description.isEmpty ? null : description,
          location: location.isEmpty ? null : location,
          startAt: _startAt,
          endAt: _endAt,
          visibility: _visibility,
          participantMemberIds: _selectedParticipantIds.toList(),
          sharedHouseholdIds: _selectedHouseholdIds.toList(),
          recurrenceFrequency: _recurrenceFrequency,
          recurrenceInterval: interval < 1 ? 1 : interval,
          recurrenceByDay: _recurrenceFrequency == RecurrenceFrequency.weekly
              ? _recurrenceByDay.toList()
              : null,
          recurrenceEndsAt:
              _recurrenceEndMode == _RecurrenceEndMode.onDate ? _recurrenceEndsAt : null,
          recurrenceOccurrenceCount: recurrenceOccurrenceCount,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;

    var deleteScope = 'this';
    if (existing.isRecurring) {
      final scope = await _pickEditScope('Delete');
      if (scope == null) return;
      deleteScope = scope;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(eventRepositoryProvider).delete(
            householdId: widget.householdId,
            eventId: int.parse(existing.id),
            scope: deleteScope,
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
    final isEditing = widget.existing != null;
    final dateFormat = DateFormat('MMM d, y  •  h:mm a');
    final members = ref.watch(currentHouseholdMembersProvider).valueOrNull ?? const <Member>[];
    final myHouseholds = ref.watch(authControllerProvider).user?.households ?? const <Household>[];
    final otherHouseholds =
        myHouseholds.where((h) => h.id != widget.householdId).toList();
    final canShareAcrossHouseholds = otherHouseholds.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isEditing ? 'Edit event' : 'New event', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        AppTextField(label: 'Title', controller: _titleController),
        const SizedBox(height: 16),
        AppTextField(label: 'Description (optional)', controller: _descriptionController),
        const SizedBox(height: 16),
        AppTextField(label: 'Location (optional)', controller: _locationController),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickDateTime(isStart: true),
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Starts'),
            child: Text(dateFormat.format(_startAt)),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickDateTime(isStart: false),
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Ends'),
            child: Text(dateFormat.format(_endAt)),
          ),
        ),
        if (!isEditing) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<RecurrenceFrequency?>(
            initialValue: _recurrenceFrequency,
            decoration: const InputDecoration(labelText: 'Repeats'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Does not repeat')),
              DropdownMenuItem(value: RecurrenceFrequency.daily, child: Text('Daily')),
              DropdownMenuItem(value: RecurrenceFrequency.weekly, child: Text('Weekly')),
              DropdownMenuItem(value: RecurrenceFrequency.monthly, child: Text('Monthly')),
            ],
            onChanged: (value) => setState(() {
              _recurrenceFrequency = value;
              if (value == RecurrenceFrequency.weekly && _recurrenceByDay.isEmpty) {
                _recurrenceByDay = {_startAt.weekday};
              }
            }),
          ),
          if (_recurrenceFrequency != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Every', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  child: AppTextField(
                    label: '',
                    controller: _recurrenceIntervalController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _recurrenceUnitLabel(
                    _recurrenceFrequency!,
                    int.tryParse(_recurrenceIntervalController.text) ?? 1,
                  ),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            if (_recurrenceFrequency == RecurrenceFrequency.weekly) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var day = 1; day <= 7; day++)
                          _WeekdayChip(
                            day: day,
                            selected: _recurrenceByDay.contains(day),
                            onTap: () => setState(() {
                              if (!_recurrenceByDay.remove(day)) {
                                _recurrenceByDay.add(day);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _recurrenceByDay = {1, 2, 3, 4, 5}),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Weekdays'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text('Ends', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                // Set a valid default the moment this mode is chosen, not
                // only once the picker below resolves -- if the user
                // dismisses the picker without picking a date, this mode
                // still has a usable value instead of silently reverting
                // to "selected but empty" (see the initial-value comment
                // on _recurrenceEndMode above).
                setState(() {
                  _recurrenceEndMode = _RecurrenceEndMode.onDate;
                  _recurrenceEndsAt ??= _startAt.add(const Duration(days: 30));
                });
                final date = await showDatePicker(
                  context: context,
                  initialDate: _recurrenceEndsAt!,
                  firstDate: _startAt,
                  lastDate: DateTime.now().add(const Duration(days: 1825)),
                );
                if (date != null) setState(() => _recurrenceEndsAt = date);
              },
              child: Row(
                children: [
                  Icon(
                    _recurrenceEndMode == _RecurrenceEndMode.onDate
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _recurrenceEndsAt == null
                        ? 'On date'
                        : 'On ${DateFormat('MMM d, y').format(_recurrenceEndsAt!)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _recurrenceEndMode = _RecurrenceEndMode.afterCount),
              child: Row(
                children: [
                  Icon(
                    _recurrenceEndMode == _RecurrenceEndMode.afterCount
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text('After'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: AppTextField(
                      label: '',
                      controller: _recurrenceOccurrenceCountController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('occurrences'),
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<EventVisibility>(
          initialValue: _visibility,
          decoration: const InputDecoration(labelText: 'Visibility'),
          items: [
            for (final visibility in EventVisibility.values)
              if (visibility != EventVisibility.selectedHouseholds &&
                      visibility != EventVisibility.allMemberHouseholds ||
                  canShareAcrossHouseholds)
                DropdownMenuItem(
                  value: visibility,
                  child: Text(_visibilityLabel(visibility)),
                ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _visibility = value);
          },
        ),
        if (_visibility == EventVisibility.selectedHouseholds) ...[
          const SizedBox(height: 16),
          Text('Share with', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final household in otherHouseholds)
                _HouseholdShareChip(
                  household: household,
                  selected: _selectedHouseholdIds.contains(household.id),
                  onTap: () => setState(() {
                    if (!_selectedHouseholdIds.remove(household.id)) {
                      _selectedHouseholdIds.add(household.id);
                    }
                  }),
                ),
            ],
          ),
        ],
        if (members.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Participants', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final entry in members.asMap().entries)
                _ParticipantChip(
                  member: entry.value,
                  colorIndex: entry.key,
                  selected: _selectedParticipantIds.contains(entry.value.id),
                  onTap: () => setState(() {
                    if (!_selectedParticipantIds.remove(entry.value.id)) {
                      _selectedParticipantIds.add(entry.value.id);
                    }
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: isEditing ? 'Save changes' : 'Add event',
          isLoading: _isLoading,
          onPressed: _submit,
        ),
        if (isEditing) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _isLoading ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: context.colors.error),
              child: const Text('Delete event'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ParticipantChip extends StatelessWidget {
  const _ParticipantChip({
    required this.member,
    required this.colorIndex,
    required this.selected,
    required this.onTap,
  });

  final Member member;
  final int colorIndex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: selected ? 1 : 0.4,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                MemberAvatar(
                  name: member.name,
                  colorIndex: colorIndex,
                  avatarUrl: member.avatarUrl,
                  size: 48,
                ),
                if (selected)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.checkCircle,
                        size: 16,
                        color: context.colors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            member.name.split(' ').first,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

/// A tappable chip for picking which of the user's *other* households a
/// `selected_households` event is shared into — the same
/// dimmed/checkmarked selection language as `_ParticipantChip`, one level
/// up (a household, not a member).
/// A single weekday toggle for the "Repeats weekly" day picker. [day] is an
/// ISO weekday (1 = Monday .. 7 = Sunday), matching both Dart's
/// [DateTime.weekday] and the API's `recurrence.by_day` values.
class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.colors.primary : null,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? context.colors.primary : context.colors.border),
        ),
        child: Text(
          _weekdayLetters[day - 1],
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? context.colors.primaryForeground : context.colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _HouseholdShareChip extends StatelessWidget {
  const _HouseholdShareChip({
    required this.household,
    required this.selected,
    required this.onTap,
  });

  final Household household;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = householdColorFromHex(context, household.color);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : context.colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(household.emoji ?? kHouseholdEmojis.first, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              household.name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? color : context.colors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(LucideIcons.checkCircle, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}
