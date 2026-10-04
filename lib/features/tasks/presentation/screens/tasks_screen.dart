import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../calendar/domain/event.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../../members/domain/member.dart';
import '../../../members/presentation/providers/member_providers.dart';
import '../../domain/task_item.dart';
import '../providers/task_providers.dart';
import '../widgets/task_list_tile.dart';

enum _StatusFilter { all, pending, overdue, completed }

/// Reached by pushing (from Home's "Chores" tile or the Tasks section's
/// "View all"), not a bottom-nav tab — the nav bar is already full at 5/5
/// (see the nav restructure that moved Family/Household settings off the
/// bar). Has its own back arrow.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  _StatusFilter _statusFilter = _StatusFilter.all;
  int? _assigneeFilter;

  Future<void> _openAddSheet() async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    final changed = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddEditTaskSheet(householdId: household.id),
    );

    if (changed == true) ref.invalidate(currentHouseholdTasksProvider);
  }

  Future<void> _openEditSheet(TaskItem task) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    final changed = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddEditTaskSheet(householdId: household.id, existing: task),
    );

    if (changed == true) ref.invalidate(currentHouseholdTasksProvider);
  }

  Future<void> _toggleComplete(TaskItem task) async {
    try {
      final repository = ref.read(taskRepositoryProvider);
      if (task.isCompleted) {
        await repository.uncomplete(householdId: task.householdId, taskId: task.id);
      } else {
        await repository.complete(householdId: task.householdId, taskId: task.id);
      }
      ref.invalidate(currentHouseholdTasksProvider);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteTask(TaskItem task) async {
    try {
      await ref.read(taskRepositoryProvider).delete(householdId: task.householdId, taskId: task.id);
      ref.invalidate(currentHouseholdTasksProvider);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  List<TaskItem> _applyFilters(List<TaskItem> tasks) {
    return tasks.where((task) {
      if (_assigneeFilter != null && task.assignedMemberId != _assigneeFilter) return false;
      return switch (_statusFilter) {
        _StatusFilter.all => true,
        _StatusFilter.pending => !task.isCompleted,
        _StatusFilter.overdue => task.isOverdue,
        _StatusFilter.completed => task.isCompleted,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(currentHouseholdTasksProvider);
    final membersAsync = ref.watch(currentHouseholdMembersProvider);
    final household = ref.watch(currentHouseholdProvider);
    final canManage = household?.myRole == 'owner' || household?.myRole == 'adult';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(LucideIcons.plus),
              onPressed: _openAddSheet,
            ),
        ],
      ),
      body: SafeArea(
        child: tasksAsync.when(
          data: (tasks) {
            final members = membersAsync.valueOrNull ?? const [];
            final filtered = _applyFilters(tasks);

            return Column(
              children: [
                if (members.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 56,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (final entry in members.asMap().entries) ...[
                          _AssigneeFilterChip(
                            member: entry.value,
                            colorIndex: entry.key,
                            selected: _assigneeFilter == entry.value.id,
                            onTap: () => setState(() {
                              _assigneeFilter =
                                  _assigneeFilter == entry.value.id ? null : entry.value.id;
                            }),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ),
                ],
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      for (final filter in _StatusFilter.values) ...[
                        _StatusChip(
                          label: _statusFilterLabel(filter),
                          selected: _statusFilter == filter,
                          onTap: () => setState(() => _statusFilter = filter),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: tasks.isEmpty
                      ? Center(
                          child: Text(
                            'No tasks yet.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Nothing matches this filter.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              children: [
                                for (final task in filtered)
                                  TaskListTile(
                                    task: task,
                                    canManage: canManage,
                                    onToggle: () => _toggleComplete(task),
                                    onEdit: canManage ? () => _openEditSheet(task) : null,
                                    onDelete: canManage ? () => _deleteTask(task) : null,
                                  ),
                              ],
                            ),
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
    );
  }
}

String _statusFilterLabel(_StatusFilter filter) => switch (filter) {
      _StatusFilter.all => 'All',
      _StatusFilter.pending => 'Pending',
      _StatusFilter.overdue => 'Overdue',
      _StatusFilter.completed => 'Completed',
    };

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
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

class _AssigneeFilterChip extends StatelessWidget {
  const _AssigneeFilterChip({
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
      child: Opacity(
        opacity: selected ? 1 : 0.5,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            MemberAvatar(name: member.name, colorIndex: colorIndex, avatarUrl: member.avatarUrl, size: 40),
            if (selected)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(color: context.colors.surface, shape: BoxShape.circle),
                  child: Icon(LucideIcons.checkCircle, size: 14, color: context.colors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


enum _RecurrenceEndMode { onDate, afterCount }

String _recurrenceUnitLabel(RecurrenceFrequency frequency, int interval) {
  final plural = interval != 1;
  return switch (frequency) {
    RecurrenceFrequency.daily => plural ? 'days' : 'day',
    RecurrenceFrequency.weekly => plural ? 'weeks' : 'week',
    RecurrenceFrequency.monthly => plural ? 'months' : 'month',
  };
}

const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class _AddEditTaskSheet extends ConsumerStatefulWidget {
  const _AddEditTaskSheet({required this.householdId, this.existing});

  final int householdId;
  final TaskItem? existing;

  @override
  ConsumerState<_AddEditTaskSheet> createState() => _AddEditTaskSheetState();
}

class _AddEditTaskSheetState extends ConsumerState<_AddEditTaskSheet> {
  late final _titleController = TextEditingController(text: widget.existing?.title ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.existing?.description ?? '');
  late DateTime _dueAt = widget.existing?.dueAt ?? DateTime.now();
  late int? _assignedMemberId = widget.existing?.assignedMemberId;

  // Recurrence is create-only (matches Calendar events) -- the edit sheet
  // never shows this section at all.
  RecurrenceFrequency? _recurrenceFrequency;
  final _recurrenceIntervalController = TextEditingController(text: '1');
  Set<int> _recurrenceByDay = {};
  _RecurrenceEndMode _recurrenceEndMode = _RecurrenceEndMode.afterCount;
  DateTime? _recurrenceEndsAt;
  final _recurrenceOccurrenceCountController = TextEditingController(text: '4');

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _recurrenceIntervalController.dispose();
    _recurrenceOccurrenceCountController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
    );
    if (date != null) setState(() => _dueAt = date);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(taskRepositoryProvider);
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();

      if (_isEditing) {
        await repository.update(
          householdId: widget.householdId,
          taskId: widget.existing!.id,
          title: title,
          description: description,
          dueAt: _dueAt,
          assignedMemberId: _assignedMemberId,
        );
      } else {
        final interval = int.tryParse(_recurrenceIntervalController.text) ?? 1;
        await repository.create(
          householdId: widget.householdId,
          title: title,
          description: description,
          dueAt: _dueAt,
          assignedMemberId: _assignedMemberId,
          recurrenceFrequency: _recurrenceFrequency,
          recurrenceInterval: interval,
          recurrenceByDay:
              _recurrenceFrequency == RecurrenceFrequency.weekly ? _recurrenceByDay.toList() : null,
          recurrenceEndsAt:
              _recurrenceEndMode == _RecurrenceEndMode.onDate ? _recurrenceEndsAt : null,
          recurrenceOccurrenceCount: _recurrenceFrequency != null &&
                  _recurrenceEndMode == _RecurrenceEndMode.afterCount
              ? int.tryParse(_recurrenceOccurrenceCountController.text)
              : null,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(currentHouseholdMembersProvider).valueOrNull ?? const [];
    final dateFormat = DateFormat('MMM d, y');

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Edit task' : 'Add task',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],
          AppTextField(label: 'Title', controller: _titleController),
          const SizedBox(height: 16),
          AppTextField(label: 'Description (optional)', controller: _descriptionController),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickDueDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Due'),
              child: Text(dateFormat.format(_dueAt)),
            ),
          ),
          if (!_isEditing) ...[
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
                  _recurrenceByDay = {_dueAt.weekday};
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
                  setState(() {
                    _recurrenceEndMode = _RecurrenceEndMode.onDate;
                    _recurrenceEndsAt ??= _dueAt.add(const Duration(days: 30));
                  });
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _recurrenceEndsAt!,
                    firstDate: _dueAt,
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
          if (members.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Assign to', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final entry in members.asMap().entries)
                  _AssigneePickerChip(
                    member: entry.value,
                    colorIndex: entry.key,
                    selected: _assignedMemberId == entry.value.id,
                    onTap: () => setState(() {
                      _assignedMemberId =
                          _assignedMemberId == entry.value.id ? null : entry.value.id;
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: _isEditing ? 'Save changes' : 'Add task',
            isLoading: _isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _AssigneePickerChip extends StatelessWidget {
  const _AssigneePickerChip({
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
                MemberAvatar(name: member.name, colorIndex: colorIndex, avatarUrl: member.avatarUrl, size: 48),
                if (selected)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(color: context.colors.surface, shape: BoxShape.circle),
                      child: Icon(LucideIcons.checkCircle, size: 16, color: context.colors.primary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(member.name.split(' ').first, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({required this.day, required this.selected, required this.onTap});

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
