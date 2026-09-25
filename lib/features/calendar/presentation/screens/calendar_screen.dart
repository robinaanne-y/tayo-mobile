import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_list_row.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../domain/event.dart';
import '../providers/event_providers.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  DateTime get _monthKey => DateTime(_focusedDay.year, _focusedDay.month, 1);

  void _refresh() {
    ref.invalidate(currentHouseholdEventsForMonthProvider(_monthKey));
    ref.invalidate(currentHouseholdTodaysEventsProvider);
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

  Future<void> _delete(Event event) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    try {
      await ref.read(eventRepositoryProvider).delete(
            householdId: household.id,
            eventId: event.id,
          );
      _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(currentHouseholdEventsForMonthProvider(_monthKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Add event',
            onPressed: () => _openAddEditSheet(),
          ),
        ],
      ),
      body: eventsAsync.when(
        data: (events) {
          final eventsByDay = <DateTime, List<Event>>{};
          for (final event in events) {
            final day = DateTime(event.startAt.year, event.startAt.month, event.startAt.day);
            eventsByDay.putIfAbsent(day, () => []).add(event);
          }

          final selectedKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
          final selectedEvents = eventsByDay[selectedKey] ?? const <Event>[];

          return Column(
            children: [
              TableCalendar<Event>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2035, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.month,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) {
                  final key = DateTime(day.year, day.month, day.day);
                  return eventsByDay[key] ?? const <Event>[];
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  setState(() => _focusedDay = focusedDay);
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: selectedEvents.isEmpty
                    ? Center(
                        child: Text(
                          'No events on this day',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.space16),
                        itemCount: selectedEvents.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.space12),
                        itemBuilder: (context, index) {
                          final event = selectedEvents[index];
                          return _EventListTile(
                            event: event,
                            onTap: () => _openAddEditSheet(existing: event),
                            onDelete: () => _delete(event),
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
    );
  }
}

class _EventListTile extends StatelessWidget {
  const _EventListTile({
    required this.event,
    required this.onTap,
    required this.onDelete,
  });

  final Event event;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: AppListRow(
        leading: SizedBox(
          width: 56,
          child: Text(
            DateFormat.jm().format(event.startAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        title: event.title,
        subtitle: event.visibility == EventVisibility.private
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.lock, size: 12, color: context.colors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Only visible to you', style: Theme.of(context).textTheme.labelMedium),
                ],
              )
            : null,
        trailing: InkWell(
          onTap: onDelete,
          customBorder: const CircleBorder(),
          // Padding brings the tap target up to the 44x44 minimum without
          // growing the visible icon, matching the pattern used for the
          // Home delete icons.
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(LucideIcons.x, size: 16, color: context.colors.textSecondary),
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

class _AddEditEventSheetState extends ConsumerState<_AddEditEventSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late DateTime _startAt;
  late DateTime _endAt;
  late EventVisibility _visibility;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description ?? '';
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
    super.dispose();
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final description = _descriptionController.text.trim();

    try {
      final repository = ref.read(eventRepositoryProvider);
      final existing = widget.existing;
      if (existing != null) {
        await repository.update(
          householdId: widget.householdId,
          eventId: existing.id,
          title: title,
          description: description.isEmpty ? null : description,
          startAt: _startAt,
          endAt: _endAt,
          visibility: _visibility,
        );
      } else {
        await repository.create(
          householdId: widget.householdId,
          title: title,
          description: description.isEmpty ? null : description,
          startAt: _startAt,
          endAt: _endAt,
          visibility: _visibility,
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
    final isEditing = widget.existing != null;
    final dateFormat = DateFormat('MMM d, y  •  h:mm a');

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
        const SizedBox(height: 16),
        SegmentedButton<EventVisibility>(
          segments: const [
            ButtonSegment(
              value: EventVisibility.household,
              label: Text('Household'),
              icon: Icon(LucideIcons.users),
            ),
            ButtonSegment(
              value: EventVisibility.private,
              label: Text('Private'),
              icon: Icon(LucideIcons.lock),
            ),
          ],
          selected: {_visibility},
          onSelectionChanged: (selection) => setState(() => _visibility = selection.first),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: isEditing ? 'Save changes' : 'Add event',
          isLoading: _isLoading,
          onPressed: _submit,
        ),
      ],
    );
  }
}
