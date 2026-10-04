import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../groceries/domain/grocery_item.dart';
import '../../../groceries/presentation/providers/grocery_providers.dart';
import '../../../groceries/presentation/widgets/grocery_item_tile.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../../members/domain/member.dart';
import '../../../members/presentation/providers/member_providers.dart';
import '../../../tasks/domain/task_item.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../../tasks/presentation/widgets/task_list_tile.dart';
import '../../domain/trip.dart';
import '../../domain/trip_itinerary_item.dart';
import '../../domain/trip_memory.dart';
import '../providers/trip_providers.dart';
import 'trips_screen.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final int tripId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  void _refresh() => ref.invalidate(tripDetailProvider(widget.tripId));

  Future<void> _openEditSheet(int householdId, Trip trip) async {
    final changed = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => AddEditTripSheet(householdId: householdId, existing: trip),
    );
    if (changed == true) {
      _refresh();
      ref.invalidate(currentHouseholdTripsProvider);
    }
  }

  Future<void> _confirmDelete(int householdId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this trip?'),
        content: const Text(
          "This removes the trip and its itinerary. Checklist items and grocery items you added "
          "stay on the household's regular lists, just no longer linked to a trip.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(tripRepositoryProvider).delete(householdId: householdId, tripId: widget.tripId);
      ref.invalidate(currentHouseholdTripsProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _changeThumbnail(int householdId) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;

    try {
      await ref.read(tripRepositoryProvider).uploadThumbnail(
            householdId: householdId,
            tripId: widget.tripId,
            filePath: picked.path,
          );
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openAddItineraryItemSheet(int householdId) async {
    final changed = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddEditItineraryItemSheet(householdId: householdId, tripId: widget.tripId),
    );
    if (changed == true) _refresh();
  }

  Future<void> _deleteItineraryItem(int householdId, TripItineraryItem item) async {
    try {
      await ref.read(tripRepositoryProvider).deleteItineraryItem(
            householdId: householdId,
            tripId: widget.tripId,
            itineraryItemId: item.id,
          );
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openAddChecklistItemSheet(int householdId) async {
    final changed = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddTripChecklistItemSheet(householdId: householdId, tripId: widget.tripId),
    );
    if (changed == true) ref.invalidate(tripTasksProvider(widget.tripId));
  }

  Future<void> _toggleChecklistItem(TaskItem task) async {
    final repository = ref.read(taskRepositoryProvider);
    if (task.isCompleted) {
      await repository.uncomplete(householdId: task.householdId, taskId: task.id);
    } else {
      await repository.complete(householdId: task.householdId, taskId: task.id);
    }
    ref.invalidate(tripTasksProvider(widget.tripId));
  }

  Future<void> _deleteChecklistItem(TaskItem task) async {
    try {
      await ref.read(taskRepositoryProvider).delete(householdId: task.householdId, taskId: task.id);
      ref.invalidate(tripTasksProvider(widget.tripId));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openAddGroceryItemSheet(int householdId) async {
    final changed = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddTripGroceryItemSheet(householdId: householdId, tripId: widget.tripId),
    );
    if (changed == true) ref.invalidate(tripGroceryItemsProvider(widget.tripId));
  }

  Future<void> _deleteGroceryItem(GroceryItem item) async {
    try {
      await ref.read(groceryItemRepositoryProvider).delete(householdId: item.householdId, itemId: item.id);
      ref.invalidate(tripGroceryItemsProvider(widget.tripId));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openMyMemorySheet(int householdId, TripMemory? existing) async {
    final changed = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddEditMemorySheet(
        householdId: householdId,
        tripId: widget.tripId,
        existing: existing,
      ),
    );
    if (changed == true) _refresh();
  }

  Future<void> _deleteMemory(int householdId, TripMemory memory) async {
    try {
      await ref.read(tripRepositoryProvider).deleteMemory(
            householdId: householdId,
            tripId: widget.tripId,
            memoryId: memory.id,
          );
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));
    final household = ref.watch(currentHouseholdProvider);
    final canManage = household?.myRole == 'owner' || household?.myRole == 'adult';
    final myMemberId = ref.watch(authControllerProvider).user?.member?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip'),
        actions: [
          if (canManage)
            tripAsync.maybeWhen(
              data: (trip) => trip == null || household == null
                  ? const SizedBox.shrink()
                  : Row(
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.pencil),
                          onPressed: () => _openEditSheet(household.id, trip),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.trash2),
                          onPressed: () => _confirmDelete(household.id),
                        ),
                      ],
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: SafeArea(
        child: tripAsync.when(
          data: (trip) {
            if (trip == null || household == null) {
              return const Center(child: Text('Trip not found.'));
            }

            final myMemory = myMemberId != null
                ? trip.memories.where((m) => m.memberId == myMemberId).firstOrNull
                : null;
            final otherMemories = trip.memories.where((m) => m.memberId != myMemberId).toList();
            final sortedItinerary = [...trip.itineraryItems]
              ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _TripHeader(trip: trip, canManage: canManage, onChangeThumbnail: () => _changeThumbnail(household.id)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Itinerary', style: Theme.of(context).textTheme.titleMedium),
                    if (canManage)
                      IconButton(
                        icon: const Icon(LucideIcons.plus, size: 20),
                        onPressed: () => _openAddItineraryItemSheet(household.id),
                      ),
                  ],
                ),
                if (sortedItinerary.isEmpty)
                  Text('No itinerary items yet.', style: Theme.of(context).textTheme.bodyMedium)
                else
                  for (final item in sortedItinerary)
                    _ItineraryItemTile(
                      item: item,
                      canManage: canManage,
                      onDelete: () => _deleteItineraryItem(household.id, item),
                    ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Checklist', style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      icon: const Icon(LucideIcons.plus, size: 20),
                      onPressed: () => _openAddChecklistItemSheet(household.id),
                    ),
                  ],
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final tasksAsync = ref.watch(tripTasksProvider(widget.tripId));
                    return tasksAsync.when(
                      data: (tasks) => tasks.isEmpty
                          ? Text('No checklist items yet.', style: Theme.of(context).textTheme.bodyMedium)
                          : Column(
                              children: [
                                for (final task in tasks)
                                  TaskListTile(
                                    task: task,
                                    canManage: canManage,
                                    onToggle: () => _toggleChecklistItem(task),
                                    onDelete: canManage ? () => _deleteChecklistItem(task) : null,
                                  ),
                              ],
                            ),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stack) => const Text("Couldn't load the checklist."),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Groceries', style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      icon: const Icon(LucideIcons.plus, size: 20),
                      onPressed: () => _openAddGroceryItemSheet(household.id),
                    ),
                  ],
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final itemsAsync = ref.watch(tripGroceryItemsProvider(widget.tripId));
                    return itemsAsync.when(
                      data: (items) => items.isEmpty
                          ? Text('No grocery items yet.', style: Theme.of(context).textTheme.bodyMedium)
                          : Column(
                              children: [
                                for (final item in items)
                                  GroceryItemTile(
                                    item: item,
                                    canManage: canManage,
                                    onToggled: () => ref.invalidate(tripGroceryItemsProvider(widget.tripId)),
                                    onEdit: () {},
                                    onDelete: () => _deleteGroceryItem(item),
                                  ),
                              ],
                            ),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stack) => const Text("Couldn't load groceries."),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text('Memories', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (myMemberId != null)
                  _MyMemoryRow(
                    memory: myMemory,
                    onTap: () => _openMyMemorySheet(household.id, myMemory),
                    onDelete: myMemory != null ? () => _deleteMemory(household.id, myMemory) : null,
                  ),
                for (final memory in otherMemories)
                  _MemoryTile(
                    memory: memory,
                    canDelete: canManage,
                    onDelete: () => _deleteMemory(household.id, memory),
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

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.trip, required this.canManage, required this.onChangeThumbnail});

  final Trip trip;
  final bool canManage;
  final VoidCallback onChangeThumbnail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: canManage ? onChangeThumbnail : null,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              image: trip.thumbnailUrl != null
                  ? DecorationImage(image: NetworkImage(trip.thumbnailUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: trip.thumbnailUrl == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.plane, size: 32, color: context.colors.primary),
                        if (canManage) ...[
                          const SizedBox(height: 8),
                          Text('Tap to add a photo', style: Theme.of(context).textTheme.labelMedium),
                        ],
                      ],
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(trip.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          [
            DateFormat('MMM d, y').format(trip.startAt),
            if (trip.endAt != null) '– ${DateFormat('MMM d, y').format(trip.endAt!)}',
          ].join(' '),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (trip.destination != null)
          Text(trip.destination!, style: Theme.of(context).textTheme.bodyMedium),
        if (trip.daysUntil != null && trip.daysUntil! > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${trip.daysUntil} day${trip.daysUntil == 1 ? '' : 's'} to go',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.colors.primary),
          ),
        ],
        if (trip.notes != null) ...[
          const SizedBox(height: 12),
          Text(trip.notes!, style: Theme.of(context).textTheme.bodyMedium),
        ],
        if (trip.participants.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in trip.participants.asMap().entries)
                MemberAvatar(
                  name: entry.value.name,
                  colorIndex: entry.key,
                  avatarUrl: entry.value.avatarUrl,
                  size: 32,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ItineraryItemTile extends StatelessWidget {
  const _ItineraryItemTile({required this.item, required this.canManage, required this.onDelete});

  final TripItineraryItem item;
  final bool canManage;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(DateFormat('h:mm a').format(item.scheduledAt), style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.bodyMedium),
                if (item.description != null)
                  Text(item.description!, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
          if (canManage)
            IconButton(
              icon: Icon(LucideIcons.trash2, size: 18, color: context.colors.error),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class _MyMemoryRow extends StatelessWidget {
  const _MyMemoryRow({required this.memory, required this.onTap, this.onDelete});

  final TripMemory? memory;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: memory == null
                ? Text('Add your memorable moment', style: Theme.of(context).textTheme.bodyMedium)
                : Text(memory!.content, style: Theme.of(context).textTheme.bodyMedium),
          ),
          TextButton(onPressed: onTap, child: Text(memory == null ? 'Add' : 'Edit')),
          if (onDelete != null)
            IconButton(
              icon: Icon(LucideIcons.trash2, size: 18, color: context.colors.error),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.memory, required this.canDelete, required this.onDelete});

  final TripMemory memory;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemberAvatar(name: memory.memberName ?? '?', colorIndex: memory.memberId, avatarUrl: memory.memberAvatarUrl, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (memory.memberName != null)
                  Text(memory.memberName!, style: Theme.of(context).textTheme.labelMedium),
                Text(memory.content, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              icon: Icon(LucideIcons.trash2, size: 18, color: context.colors.error),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class _AddEditItineraryItemSheet extends ConsumerStatefulWidget {
  const _AddEditItineraryItemSheet({required this.householdId, required this.tripId});

  final int householdId;
  final int tripId;

  @override
  ConsumerState<_AddEditItineraryItemSheet> createState() => _AddEditItineraryItemSheetState();
}

class _AddEditItineraryItemSheetState extends ConsumerState<_AddEditItineraryItemSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _scheduledAt = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_scheduledAt));
    if (time == null) return;

    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(tripRepositoryProvider).addItineraryItem(
            householdId: widget.householdId,
            tripId: widget.tripId,
            title: title,
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            scheduledAt: _scheduledAt,
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
        Text('Add itinerary item', style: Theme.of(context).textTheme.titleLarge),
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
          onTap: _pickDateTime,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'When'),
            child: Text(DateFormat('MMM d, y · h:mm a').format(_scheduledAt)),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Add item', isLoading: _isLoading, onPressed: _submit),
      ],
    );
  }
}

class _AddTripChecklistItemSheet extends ConsumerStatefulWidget {
  const _AddTripChecklistItemSheet({required this.householdId, required this.tripId});

  final int householdId;
  final int tripId;

  @override
  ConsumerState<_AddTripChecklistItemSheet> createState() => _AddTripChecklistItemSheetState();
}

class _AddTripChecklistItemSheetState extends ConsumerState<_AddTripChecklistItemSheet> {
  final _titleController = TextEditingController();
  int? _assignedMemberId;
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
      final trip = await ref.read(tripRepositoryProvider).show(
            householdId: widget.householdId,
            tripId: widget.tripId,
          );
      await ref.read(taskRepositoryProvider).create(
            householdId: widget.householdId,
            title: title,
            dueAt: trip.endAt ?? trip.startAt,
            assignedMemberId: _assignedMemberId,
            tripId: widget.tripId,
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
    final members = ref.watch(currentHouseholdMembersProvider).valueOrNull ?? const [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add checklist item', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        AppTextField(label: 'Title', controller: _titleController),
        if (members.isNotEmpty) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            initialValue: _assignedMemberId,
            decoration: const InputDecoration(labelText: 'Assign to (optional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Unassigned')),
              for (final Member member in members)
                DropdownMenuItem(value: member.id, child: Text(member.name)),
            ],
            onChanged: (value) => setState(() => _assignedMemberId = value),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(label: 'Add item', isLoading: _isLoading, onPressed: _submit),
      ],
    );
  }
}

class _AddTripGroceryItemSheet extends ConsumerStatefulWidget {
  const _AddTripGroceryItemSheet({required this.householdId, required this.tripId});

  final int householdId;
  final int tripId;

  @override
  ConsumerState<_AddTripGroceryItemSheet> createState() => _AddTripGroceryItemSheetState();
}

class _AddTripGroceryItemSheetState extends ConsumerState<_AddTripGroceryItemSheet> {
  final _nameController = TextEditingController();
  String? _category;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(groceryItemRepositoryProvider).create(
            householdId: widget.householdId,
            name: name,
            category: _category,
            tripId: widget.tripId,
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
        Text('Add grocery item', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        AppTextField(label: 'Item name', controller: _nameController),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Category (optional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('No category')),
            for (final category in kGroceryCategories)
              DropdownMenuItem(value: category, child: Text(category)),
          ],
          onChanged: (value) => setState(() => _category = value),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Add item', isLoading: _isLoading, onPressed: _submit),
      ],
    );
  }
}

class _AddEditMemorySheet extends ConsumerStatefulWidget {
  const _AddEditMemorySheet({required this.householdId, required this.tripId, this.existing});

  final int householdId;
  final int tripId;
  final TripMemory? existing;

  @override
  ConsumerState<_AddEditMemorySheet> createState() => _AddEditMemorySheetState();
}

class _AddEditMemorySheetState extends ConsumerState<_AddEditMemorySheet> {
  late final _contentController = TextEditingController(text: widget.existing?.content ?? '');
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(tripRepositoryProvider).setMyMemory(
            householdId: widget.householdId,
            tripId: widget.tripId,
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
        Text('Your memory', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'What do you remember most about this trip?',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        AppTextField(label: 'Memory', controller: _contentController),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Save', isLoading: _isLoading, onPressed: _submit),
      ],
    );
  }
}
