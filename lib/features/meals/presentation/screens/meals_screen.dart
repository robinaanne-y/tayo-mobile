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

bool _canManageMeals(WidgetRef ref) {
  final household = ref.watch(currentHouseholdProvider);
  return household?.myRole == 'owner' || household?.myRole == 'adult';
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
    final daysSinceSunday = _selectedDay.weekday % 7;
    final start = _selectedDay.subtract(Duration(days: daysSinceSunday));
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
              slot: slot,
              suggestedTitle: existing?.title,
            ),
    );

    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final range = _weekRange;
    final planAsync = ref.watch(currentHouseholdMealPlanProvider(range));

    return Scaffold(
      body: SafeArea(
        child: planAsync.when(
          data: (items) {
            final itemsByDaySlot = <DateTime, Map<MealSlot, MealPlanItem>>{};
            for (final item in items) {
              final key = DateTime(item.date.year, item.date.month, item.date.day);
              (itemsByDaySlot[key] ??= {})[item.slot] = item;
            }

            final selectedKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
            final todaysItems = itemsByDaySlot[selectedKey] ?? const <MealSlot, MealPlanItem>{};

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Meals', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
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
                const SizedBox(height: 20),
                Text('Requests', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const _MealRequestsSection(),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text(error is ApiException ? error.message : 'Something went wrong.'),
          ),
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
    required this.slot,
    this.suggestedTitle,
  });

  final int householdId;
  final DateTime date;
  final MealSlot slot;
  final String? suggestedTitle;

  @override
  ConsumerState<_RequestMealSheet> createState() => _RequestMealSheetState();
}

class _RequestMealSheetState extends ConsumerState<_RequestMealSheet> {
  late final _titleController = TextEditingController(text: widget.suggestedTitle ?? '');
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
            requestedSlot: widget.slot,
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
          'Request ${_slotLabel(widget.slot).toLowerCase()} · ${DateFormat('MMM d').format(widget.date)}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        AppTextField(label: 'What do you want to eat?', controller: _titleController),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Send request', isLoading: _isLoading, onPressed: _submit),
      ],
    );
  }
}

class _MealRequestsSection extends ConsumerStatefulWidget {
  const _MealRequestsSection();

  @override
  ConsumerState<_MealRequestsSection> createState() => _MealRequestsSectionState();
}

class _MealRequestsSectionState extends ConsumerState<_MealRequestsSection> {
  RequestStatus? _filter = RequestStatus.pending;

  Future<void> _openDetail(MealRequest request) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => MealRequestDetailSheet(householdId: household.id, request: request),
    );
    ref.invalidate(currentHouseholdMealRequestsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(currentHouseholdMealRequestsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in [null, ...RequestStatus.values]) ...[
                _MealFilterChip(
                  label: option == null ? 'All' : _statusLabel(option),
                  selected: _filter == option,
                  onTap: () => setState(() => _filter = option),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        requestsAsync.when(
          data: (requests) {
            final visible =
                _filter == null ? requests : requests.where((r) => r.status == _filter).toList();

            if (visible.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No requests here yet.', style: Theme.of(context).textTheme.bodyMedium),
              );
            }

            return Column(
              children: [
                for (final request in visible) ...[
                  _MealRequestTile(request: request, onTap: () => _openDetail(request)),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Text(
            error is ApiException ? error.message : 'Something went wrong.',
          ),
        ),
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

class _MealRequestTile extends StatelessWidget {
  const _MealRequestTile({required this.request, required this.onTap});

  final MealRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          leading: Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: _statusColor(context, request.status),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          title: request.title,
          subtitle: Text(
            '${request.requesterName} · ${_slotLabel(request.requestedSlot)}, '
            '${DateFormat('MMM d').format(request.requestedDate)} · ${_statusLabel(request.status)}',
            style: Theme.of(context).textTheme.labelMedium,
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
