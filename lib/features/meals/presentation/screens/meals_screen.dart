import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_list_row.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../../requests/domain/permission_request.dart' show RequestStatus;
import '../../domain/meal_plan_item.dart';
import '../../domain/meal_request.dart';
import '../providers/meal_providers.dart';

String _slotLabel(MealSlot slot) => switch (slot) {
      MealSlot.breakfast => 'Breakfast',
      MealSlot.lunch => 'Lunch',
      MealSlot.dinner => 'Dinner',
    };

IconData _slotIcon(MealSlot slot) => switch (slot) {
      MealSlot.breakfast => LucideIcons.coffee,
      MealSlot.lunch => LucideIcons.sandwich,
      MealSlot.dinner => LucideIcons.utensils,
    };

String _statusLabel(RequestStatus status) => switch (status) {
      RequestStatus.pending => 'Pending',
      RequestStatus.approved => 'Approved',
      RequestStatus.declined => 'Declined',
      RequestStatus.cancelled => 'Cancelled',
      RequestStatus.expired => 'Expired',
    };

Color _statusColor(BuildContext context, RequestStatus status) => switch (status) {
      RequestStatus.pending => context.colors.accent,
      RequestStatus.approved => context.colors.primary,
      RequestStatus.declined => context.colors.error,
      RequestStatus.cancelled => context.colors.textSecondary,
      RequestStatus.expired => context.colors.textSecondary,
    };

/// When the household has designated a meal approver, that one member
/// fully replaces the role check -- not additive -- so even the Owner
/// must go through the request flow. With no approver set, any Owner/
/// Adult manages, same as before. Mirrors `HouseholdPolicy::addMealPlanItem`
/// exactly.
bool _canManageMeals(WidgetRef ref) {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return false;

  final approverId = household.mealApproverMemberId;
  if (approverId != null) {
    final myMemberId = ref.watch(authControllerProvider).user?.member?.id;
    return myMemberId == approverId;
  }

  return household.myRole == 'owner' || household.myRole == 'adult';
}

/// A bottom-nav tab (like Calendar/Groceries), not a pushed route.
class MealsScreen extends ConsumerStatefulWidget {
  const MealsScreen({super.key});

  @override
  ConsumerState<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends ConsumerState<MealsScreen> {
  DateTime _selectedDay = DateTime.now();

  DateTime get _weekStart {
    final daysSinceMonday = (_selectedDay.weekday - 1) % 7;
    final start = _selectedDay.subtract(Duration(days: daysSinceMonday));
    return DateTime(start.year, start.month, start.day);
  }

  ({DateTime start, DateTime end}) get _weekRange {
    final start = _weekStart;
    final end = start.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
    return (start: start, end: end);
  }

  void _selectDay(DateTime day) => setState(() => _selectedDay = day);

  void _refresh() {
    ref.invalidate(currentHouseholdMealPlanProvider(_weekRange));
    ref.invalidate(currentHouseholdMealRequestsProvider);
    // Home's "Today's Meals" section reads a separate provider (today-only,
    // not keyed by this screen's week range) — it needs its own invalidation
    // or an edit made here would leave Home showing stale data.
    ref.invalidate(currentHouseholdTodaysMealsProvider);
  }

  Future<void> _openSlotSheet(MealSlot slot, MealPlanItem? existing) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    final canManage = _canManageMeals(ref);

    final changed = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => canManage
          ? _EditMealSlotSheet(
              householdId: household.id,
              date: _selectedDay,
              slot: slot,
              existing: existing,
            )
          : _RequestMealSheet(
              householdId: household.id,
              date: _selectedDay,
              initialSlot: slot,
              suggestedTitle: existing?.title,
            ),
    );

    if (changed == true) _refresh();
  }

  /// The header "+ Request" action — available to everyone regardless of
  /// `canManage` (including the approver themself, since the backend
  /// already allows any member to create a request), unlike tapping a
  /// slot card directly which only requests when the viewer can't manage.
  Future<void> _openRequestSheet() async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    final changed = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _RequestMealSheet(
        householdId: household.id,
        date: _selectedDay,
        initialSlot: MealSlot.breakfast,
      ),
    );

    if (changed == true) _refresh();
  }

  Future<void> _respondToRequest(MealRequest request, {required bool approve}) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    final repository = ref.read(mealRequestRepositoryProvider);
    try {
      if (approve) {
        await repository.approve(householdId: household.id, requestId: request.id);
      } else {
        await repository.decline(householdId: household.id, requestId: request.id);
      }
      _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _openRequestDetail(MealRequest request) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => MealRequestDetailSheet(householdId: household.id, request: request),
    );
    _refresh();
  }

  /// `pendingRequests` (sorted by date) rendered as cards with a date-group
  /// header inserted whenever the day changes — "Today" or "Friday, Oct 3"
  /// above the one or more requests that target it.
  List<Widget> _groupedRequestCards(List<MealRequest> pendingRequests) {
    final widgets = <Widget>[];
    DateTime? lastGroupDate;

    for (final request in pendingRequests) {
      final requestKey =
          DateTime(request.requestedDate.year, request.requestedDate.month, request.requestedDate.day);
      if (lastGroupDate == null || requestKey != lastGroupDate) {
        if (lastGroupDate != null) widgets.add(const SizedBox(height: 14));
        widgets.add(
          Text(
            _requestGroupDateLabel(request.requestedDate),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        );
        widgets.add(const SizedBox(height: 8));
        lastGroupDate = requestKey;
      }

      widgets.add(
        _PendingMealRequestCard(
          request: request,
          onApprove: () => _respondToRequest(request, approve: true),
          onDecline: () => _respondToRequest(request, approve: false),
          onTap: () => _openRequestDetail(request),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final range = _weekRange;
    final planAsync = ref.watch(currentHouseholdMealPlanProvider(range));
    final requestsAsync = ref.watch(currentHouseholdMealRequestsProvider);
    final canManage = _canManageMeals(ref);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: context.colors.surface,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Meals', style: Theme.of(context).textTheme.headlineSmall),
                  ElevatedButton.icon(
                    onPressed: _openRequestSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: context.colors.primaryForeground,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Request'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: planAsync.when(
                data: (items) {
                  final itemsByDaySlot = <DateTime, Map<MealSlot, MealPlanItem>>{};
                  for (final item in items) {
                    final key = DateTime(item.date.year, item.date.month, item.date.day);
                    (itemsByDaySlot[key] ??= {})[item.slot] = item;
                  }

                  final selectedKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
                  final todaysItems = itemsByDaySlot[selectedKey] ?? const <MealSlot, MealPlanItem>{};

                  // Every pending request, regardless of which day it
                  // targets — the approver needs to see it well before its
                  // date to have time to prepare/shop, not just when
                  // viewing that exact day. Only visible to whoever can act
                  // on requests (the approver, or any Owner/Adult when none
                  // is set); approved/declined/expired ones aren't shown —
                  // there's nothing left to do with them here.
                  final pendingRequests = canManage
                      ? ((requestsAsync.valueOrNull ?? const <MealRequest>[])
                              .where((r) => r.status == RequestStatus.pending)
                              .toList()
                            ..sort((a, b) => a.requestedDate.compareTo(b.requestedDate)))
                      : const <MealRequest>[];

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _MealWeekStrip(
                        weekStart: range.start,
                        selectedDay: _selectedDay,
                        itemsByDay: itemsByDaySlot,
                        onDaySelected: _selectDay,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        DateFormat('EEEE, MMM d').format(_selectedDay),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final slot in MealSlot.values) ...[
                        _MealSlotCard(
                          slot: slot,
                          item: todaysItems[slot],
                          onTap: () => _openSlotSheet(slot, todaysItems[slot]),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (pendingRequests.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('Requests', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ..._groupedRequestCards(pendingRequests),
                      ],
                      const SizedBox(height: 20),
                      Text('Week Overview', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _WeekOverviewTable(
                        weekStart: range.start,
                        selectedDay: _selectedDay,
                        itemsByDay: itemsByDaySlot,
                        onDaySelected: _selectDay,
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text(error is ApiException ? error.message : 'Something went wrong.'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealWeekStrip extends StatelessWidget {
  const _MealWeekStrip({
    required this.weekStart,
    required this.selectedDay,
    required this.itemsByDay,
    required this.onDaySelected,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final Map<DateTime, Map<MealSlot, MealPlanItem>> itemsByDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final day = weekStart.add(Duration(days: i));
        final key = DateTime(day.year, day.month, day.day);
        final isSelected = key == DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
        final plannedCount = itemsByDay[key]?.length ?? 0;

        return Expanded(
          child: GestureDetector(
            onTap: () => onDaySelected(day),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? context.colors.primary : context.colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? context.colors.primary : context.colors.border),
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
                    child: plannedCount == 0
                        ? null
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var j = 0; j < plannedCount && j < 3; j++)
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? context.colors.primaryForeground
                                        : context.colors.primary,
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
    );
  }
}

/// "today", "on friday" for a date within the next week, else "on Mon, Oct
/// 5" — used by `_PendingMealRequestCard` so a request reads naturally
/// regardless of which day it targets.
String _requestDayLabel(DateTime date) {
  final today = DateUtils.dateOnly(DateTime.now());
  final diff = DateUtils.dateOnly(date).difference(today).inDays;
  if (diff == 0) return 'today';
  if (diff > 0 && diff < 7) return 'on ${DateFormat('EEEE').format(date).toLowerCase()}';
  return 'on ${DateFormat('EEE, MMM d').format(date)}';
}

/// "Today" or "Friday, Oct 3" — the date-group header above the requests
/// that target that day, in `_MealsScreenState`'s grouped pending list.
String _requestGroupDateLabel(DateTime date) {
  final today = DateUtils.dateOnly(DateTime.now());
  if (DateUtils.dateOnly(date) == today) return 'Today';
  return DateFormat('EEEE, MMM d').format(date);
}

/// A compact "{requester} requested {title} for {slot} {day}" card with
/// quick Approve/Decline actions below the text, shown to whoever can act
/// on requests (the approver, or any Owner/Adult when none is set).
/// Tapping the card itself (not the buttons) opens the full detail sheet
/// for finer control (a response note, moving the date/slot).
class _PendingMealRequestCard extends StatelessWidget {
  const _PendingMealRequestCard({
    required this.request,
    required this.onApprove,
    required this.onDecline,
    required this.onTap,
  });

  final MealRequest request;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.error.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_slotIcon(request.requestedSlot), size: 18, color: context.colors.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${request.requesterName} requested ${request.title} for '
                    '${_slotLabel(request.requestedSlot).toLowerCase()} '
                    '${_requestDayLabel(request.requestedDate)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              // Aligns the buttons with the text above, not the icon —
              // matches the icon's width (18) plus its gap (10).
              padding: const EdgeInsets.only(left: 28),
              child: Row(
                children: [
                  _MealActionPill(
                    label: 'Approve',
                    background: context.colors.primary,
                    foreground: context.colors.primaryForeground,
                    onPressed: onApprove,
                  ),
                  const SizedBox(width: 8),
                  _MealActionPill(
                    label: 'Decline',
                    background: context.colors.error.withValues(alpha: 0.12),
                    foreground: context.colors.error,
                    onPressed: onDecline,
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

class _MealActionPill extends StatelessWidget {
  const _MealActionPill({
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      child: Text(label),
    );
  }
}

/// A 7-row x 3-column glance at the whole week's plan, built from the
/// same `itemsByDaySlot` map the day view already computes from the
/// already-fetched week range — no extra data fetching. Tapping a row
/// selects that day, same as the week strip above.
class _WeekOverviewTable extends StatelessWidget {
  const _WeekOverviewTable({
    required this.weekStart,
    required this.selectedDay,
    required this.itemsByDay,
    required this.onDaySelected,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final Map<DateTime, Map<MealSlot, MealPlanItem>> itemsByDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: context.colors.textSecondary, fontWeight: FontWeight.w700);

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                const SizedBox(width: 48),
                for (final slot in MealSlot.values)
                  Expanded(
                    child: Text(
                      _slotLabel(slot).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: headerStyle,
                    ),
                  ),
              ],
            ),
          ),
          for (final entry in List.generate(7, (i) => weekStart.add(Duration(days: i))).asMap().entries) ...[
            if (entry.key > 0) Divider(height: 1, color: context.colors.border),
            _WeekOverviewRow(
              day: entry.value,
              isSelected: DateTime(entry.value.year, entry.value.month, entry.value.day) ==
                  DateTime(selectedDay.year, selectedDay.month, selectedDay.day),
              items: itemsByDay[DateTime(entry.value.year, entry.value.month, entry.value.day)] ??
                  const <MealSlot, MealPlanItem>{},
              onTap: () => onDaySelected(entry.value),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekOverviewRow extends StatelessWidget {
  const _WeekOverviewRow({
    required this.day,
    required this.isSelected,
    required this.items,
    required this.onTap,
  });

  final DateTime day;
  final bool isSelected;
  final Map<MealSlot, MealPlanItem> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? context.colors.primary.withValues(alpha: 0.06) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                DateFormat.E().format(day).substring(0, 3),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected ? context.colors.primary : context.colors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ),
            for (final slot in MealSlot.values)
              Expanded(
                child: Text(
                  items[slot]?.title ?? '—',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: items[slot] == null ? context.colors.textSecondary : null,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MealSlotCard extends ConsumerWidget {
  const _MealSlotCard({required this.slot, required this.item, required this.onTap});

  final MealSlot slot;
  final MealPlanItem? item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = _canManageMeals(ref);

    return AppCard(
      onTap: onTap,
      child: AppListRow(
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_slotIcon(slot), color: context.colors.primary, size: 18),
        ),
        title: _slotLabel(slot),
        subtitle: Text(
          item?.title ?? (canManage ? 'Tap to set a meal' : 'Nothing planned — tap to request'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: item == null ? context.colors.textSecondary : null,
              ),
        ),
        trailing: Icon(LucideIcons.chevronRight, size: 18, color: context.colors.textSecondary),
      ),
    );
  }
}

class _EditMealSlotSheet extends ConsumerStatefulWidget {
  const _EditMealSlotSheet({
    required this.householdId,
    required this.date,
    required this.slot,
    this.existing,
  });

  final int householdId;
  final DateTime date;
  final MealSlot slot;
  final MealPlanItem? existing;

  @override
  ConsumerState<_EditMealSlotSheet> createState() => _EditMealSlotSheetState();
}

class _EditMealSlotSheetState extends ConsumerState<_EditMealSlotSheet> {
  late final _titleController = TextEditingController(text: widget.existing?.title ?? '');
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(mealPlanRepositoryProvider).set(
            householdId: widget.householdId,
            date: widget.date,
            slot: widget.slot,
            title: title,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clear() async {
    final existing = widget.existing;
    if (existing == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(mealPlanRepositoryProvider).delete(
            householdId: widget.householdId,
            itemId: existing.id,
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
        Text(
          '${_slotLabel(widget.slot)} · ${DateFormat('MMM d').format(widget.date)}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        AppTextField(label: 'Meal', controller: _titleController),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Save', isLoading: _isLoading, onPressed: _save),
        if (widget.existing != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _isLoading ? null : _clear,
              style: TextButton.styleFrom(foregroundColor: context.colors.error),
              child: const Text('Clear this meal'),
            ),
          ),
        ],
      ],
    );
  }
}

class _RequestMealSheet extends ConsumerStatefulWidget {
  const _RequestMealSheet({
    required this.householdId,
    required this.date,
    required this.initialSlot,
    this.suggestedTitle,
  });

  final int householdId;
  final DateTime date;
  final MealSlot initialSlot;
  final String? suggestedTitle;

  @override
  ConsumerState<_RequestMealSheet> createState() => _RequestMealSheetState();
}

class _RequestMealSheetState extends ConsumerState<_RequestMealSheet> {
  late final _titleController = TextEditingController(text: widget.suggestedTitle ?? '');
  late MealSlot _slot = widget.initialSlot;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(mealRequestRepositoryProvider).create(
            householdId: widget.householdId,
            requestedDate: widget.date,
            requestedSlot: _slot,
            title: title,
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
        Text(
          'Request a meal · ${DateFormat('MMM d').format(widget.date)}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            for (final slot in MealSlot.values) ...[
              Expanded(
                child: _MealFilterChip(
                  label: _slotLabel(slot),
                  selected: _slot == slot,
                  onTap: () => setState(() => _slot = slot),
                ),
              ),
              if (slot != MealSlot.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(label: 'What do you want to eat?', controller: _titleController),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Send request', isLoading: _isLoading, onPressed: _submit),
      ],
    );
  }
}


class _MealFilterChip extends StatelessWidget {
  const _MealFilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.colors.primary.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? context.colors.primary : context.colors.border),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? context.colors.primary : context.colors.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

/// Public so Home's unified notifications sheet can open it directly for a
/// meal request, mirroring `RequestDetailSheet` from the requests feature.
class MealRequestDetailSheet extends ConsumerStatefulWidget {
  const MealRequestDetailSheet({super.key, required this.householdId, required this.request});

  final int householdId;
  final MealRequest request;

  @override
  ConsumerState<MealRequestDetailSheet> createState() => _MealRequestDetailSheetState();
}

class _MealRequestDetailSheetState extends ConsumerState<MealRequestDetailSheet> {
  final _responseNoteController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.request.needsRequesterAttention) {
      ref.read(mealRequestRepositoryProvider).acknowledge(
            householdId: widget.householdId,
            requestId: widget.request.id,
          );
    }
  }

  @override
  void dispose() {
    _responseNoteController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(mealRequestRepositoryProvider).approve(
            householdId: widget.householdId,
            requestId: widget.request.id,
            responseNote:
                _responseNoteController.text.trim().isEmpty ? null : _responseNoteController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _decline() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(mealRequestRepositoryProvider).decline(
            householdId: widget.householdId,
            requestId: widget.request.id,
            responseNote:
                _responseNoteController.text.trim().isEmpty ? null : _responseNoteController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(mealRequestRepositoryProvider).cancel(
            householdId: widget.householdId,
            requestId: widget.request.id,
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
    final request = widget.request;
    final myMemberId = ref.watch(authControllerProvider).user?.member?.id;
    final canManage = _canManageMeals(ref);
    final canAct = canManage && myMemberId != request.requesterMemberId && request.status == RequestStatus.pending;
    final isRequester = myMemberId == request.requesterMemberId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(request.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '${request.requesterName} · ${_statusLabel(request.status)}',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: _statusColor(context, request.status)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(_slotIcon(request.requestedSlot), size: 16, color: context.colors.textSecondary),
            const SizedBox(width: 6),
            Text(
              '${_slotLabel(request.requestedSlot)}, ${DateFormat('MMM d, y').format(request.requestedDate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        if (request.responseNote != null && request.responseNote!.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Text(
              '"${request.responseNote}" — ${request.respondedByName ?? ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        ],
        if (canAct) ...[
          const SizedBox(height: 20),
          AppTextField(label: 'Response note (optional)', controller: _responseNoteController),
          const SizedBox(height: 12),
          PrimaryButton(label: 'Approve', isLoading: _isLoading, onPressed: _approve),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _isLoading ? null : _decline,
              style: TextButton.styleFrom(foregroundColor: context.colors.error),
              child: const Text('Decline'),
            ),
          ),
        ] else if (isRequester && request.status == RequestStatus.pending) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _isLoading ? null : _cancel,
              style: TextButton.styleFrom(foregroundColor: context.colors.error),
              child: const Text('Cancel request'),
            ),
          ),
        ],
      ],
    );
  }
}
