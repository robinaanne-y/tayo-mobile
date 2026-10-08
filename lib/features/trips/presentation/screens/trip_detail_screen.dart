import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/config/env.dart';
import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../../shared/widgets/participant_avatar_stack.dart';
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
  int _tabIndex = 0;

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
      final bytes = await picked.readAsBytes();
      await ref.read(tripRepositoryProvider).uploadThumbnail(
            householdId: householdId,
            tripId: widget.tripId,
            bytes: bytes,
            filename: picked.name,
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
      body: tripAsync.when(
        data: (trip) {
          if (trip == null || household == null) {
            return const SafeArea(child: Center(child: Text('Trip not found.')));
          }

          final myMemory = myMemberId != null
              ? trip.memories.where((m) => m.memberId == myMemberId).firstOrNull
              : null;
          final otherMemories = trip.memories.where((m) => m.memberId != myMemberId).toList();
          final sortedItinerary = [...trip.itineraryItems]
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          // Past trips are a memory album, not a plan -- editing the trip
          // itself (or its itinerary/checklist/groceries) no longer makes
          // sense once it's over. The cover photo and memories stay
          // editable regardless, since those are the explicit past-trip
          // feature.
          final canEdit = canManage && trip.isUpcoming;
          // A finished trip has nothing left to pack or shop for -- the
          // Checklist/Groceries tabs would just be stale, empty-feeling
          // noise, so they're dropped entirely rather than shown read-only.
          final tabLabels = trip.isUpcoming
              ? const ['Overview', 'Itinerary', 'Checklist', 'Groceries', 'Memories']
              : const ['Overview', 'Itinerary', 'Memories'];
          final tabWidgets = [
            _OverviewTab(trip: trip, tripId: widget.tripId),
            _ItineraryTab(
              items: sortedItinerary,
              canManage: canEdit,
              onAdd: () => _openAddItineraryItemSheet(household.id),
              onDelete: (item) => _deleteItineraryItem(household.id, item),
            ),
            if (trip.isUpcoming) ...[
              _ChecklistTab(
                tripId: widget.tripId,
                canManage: canEdit,
                onAdd: () => _openAddChecklistItemSheet(household.id),
                onToggle: _toggleChecklistItem,
                onDelete: _deleteChecklistItem,
              ),
              _GroceriesTab(
                tripId: widget.tripId,
                canManage: canEdit,
                onAdd: () => _openAddGroceryItemSheet(household.id),
                onDelete: _deleteGroceryItem,
              ),
            ],
            _MemoriesTab(
              myMemberId: myMemberId,
              myMemory: myMemory,
              otherMemories: otherMemories,
              canManage: canManage,
              onTapMine: () => _openMyMemorySheet(household.id, myMemory),
              onDeleteMine: myMemory != null ? () => _deleteMemory(household.id, myMemory) : null,
              onDeleteOther: (memory) => _deleteMemory(household.id, memory),
            ),
          ];
          final safeTabIndex = _tabIndex >= tabWidgets.length ? 0 : _tabIndex;

          return Column(
            children: [
              _TripHeroHeader(
                trip: trip,
                canManage: canManage,
                canEdit: canEdit,
                onChangeThumbnail: () => _changeThumbnail(household.id),
                onEdit: () => _openEditSheet(household.id, trip),
                onDelete: () => _confirmDelete(household.id),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: _TripTabBar(
                          labels: tabLabels,
                          index: safeTabIndex,
                          onChanged: (i) => setState(() => _tabIndex = i),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: IndexedStack(index: safeTabIndex, children: tabWidgets),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const SafeArea(child: Center(child: CircularProgressIndicator())),
        error: (error, stack) => SafeArea(
          child: Center(
            child: Text(error is ApiException ? error.message : 'Something went wrong.'),
          ),
        ),
      ),
    );
  }
}

String _dateRangeLabel(Trip trip) {
  final start = trip.startAt;
  final end = trip.endAt;
  if (end == null) return DateFormat('MMM d, y').format(start);
  if (start.year == end.year && start.month == end.month) {
    return '${DateFormat('MMM d').format(start)}–${DateFormat('d, y').format(end)}';
  }
  if (start.year == end.year) {
    return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, y').format(end)}';
  }
  return '${DateFormat('MMM d, y').format(start)} – ${DateFormat('MMM d, y').format(end)}';
}

/// Full-bleed cover photo with the trip's days-to-go/title/location text
/// overlaid at the bottom (behind a dark scrim for legibility), and
/// floating back/edit/delete controls up top — replaces the old AppBar for
/// this screen entirely. Tapping the photo lets an adult change it.
class _TripHeroHeader extends StatelessWidget {
  const _TripHeroHeader({
    required this.trip,
    required this.canManage,
    required this.canEdit,
    required this.onChangeThumbnail,
    required this.onEdit,
    required this.onDelete,
  });

  final Trip trip;
  final bool canManage;
  final bool canEdit;
  final VoidCallback onChangeThumbnail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 300,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: canManage ? onChangeThumbnail : null,
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.primaryStrong,
                image: trip.thumbnailUrl != null
                    ? DecorationImage(
                        image: NetworkImage('${Env.mediaBaseUrl}${trip.thumbnailUrl}'),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: trip.thumbnailUrl == null
                  ? const Center(child: Icon(LucideIcons.image, size: 40, color: Colors.white70))
                  : null,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.4, 1.0],
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 12,
            left: 16,
            child: _CircleIconButton(
              icon: LucideIcons.chevronLeft,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          if (canEdit)
            Positioned(
              top: topInset + 12,
              right: 16,
              child: Row(
                children: [
                  _CircleIconButton(icon: LucideIcons.pencil, onTap: onEdit),
                  const SizedBox(width: 8),
                  _CircleIconButton(icon: LucideIcons.trash2, onTap: onDelete),
                ],
              ),
            ),
          Positioned(
            left: 20,
            right: canManage ? 64 : 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.isUpcoming && trip.daysUntil != null && trip.daysUntil! > 0
                      ? '${trip.daysUntil} DAY${trip.daysUntil == 1 ? '' : 'S'} TO GO'
                      : (trip.isUpcoming ? 'UPCOMING TRIP' : 'PAST TRIP'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  trip.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  [_dateRangeLabel(trip), if (trip.destination != null) trip.destination!].join(' · '),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          if (canManage)
            Positioned(
              right: 16,
              bottom: 20,
              child: _CircleIconButton(icon: LucideIcons.camera, onTap: onChangeThumbnail),
            ),
        ],
      ),
    );
  }
}

/// White floating circular icon button over the hero photo — back, edit,
/// delete all share this look.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: Colors.black87),
        ),
      ),
    );
  }
}

/// Scrollable pill-in-track segmented control switching between the trip's
/// tabs — a lavender track with a white inset pill for the selected tab.
/// `labels` varies by trip: a past trip drops Checklist/Groceries (see
/// their omission from `tabWidgets` in the build method above).
class _TripTabBar extends StatelessWidget {
  const _TripTabBar({required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              _TripTabChip(label: labels[i], selected: i == index, onTap: () => onChanged(i)),
              if (i != labels.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripTabChip extends StatelessWidget {
  const _TripTabChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? context.colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? context.colors.textPrimary : context.colors.primary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

/// Who's joining / about / checklist-progress summary — the default tab.
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.trip, required this.tripId});

  final Trip trip;
  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tripTasksProvider(tripId));
    final members = ref.watch(currentHouseholdMembersProvider).valueOrNull ?? const <Member>[];
    final colorForMember = {
      for (final entry in members.asMap().entries) entry.value.id: AppColors.memberColor(entry.key),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        if (trip.participants.isNotEmpty)
          _OverviewCard(
            child: Row(
              children: [
                ParticipantAvatarStack(
                  participants: trip.participants,
                  colorForMember: colorForMember,
                  size: 32,
                  maxShown: 5,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${trip.participants.length} joining',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        if (trip.participants.isNotEmpty) const SizedBox(height: 16),
        _OverviewCard(
          child: Text(
            (trip.notes?.isNotEmpty ?? false) ? trip.notes! : 'No description yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        tasksAsync.when(
          data: (tasks) {
            final total = tasks.length;
            final completed = tasks.where((t) => t.isCompleted).length;
            final progress = total == 0 ? 0.0 : completed / total;
            return _OverviewCard(
              title: 'Ready to go',
              trailing: Text(
                '$completed of $total',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: context.colors.surfaceAlt,
                      color: context.colors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    total == 0 ? 'No checklist items yet.' : '${(progress * 100).round()}% ready to go',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({this.title, required this.child, this.trailing});

  final String? title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title!, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _ItineraryTab extends StatelessWidget {
  const _ItineraryTab({
    required this.items,
    required this.canManage,
    required this.onAdd,
    required this.onDelete,
  });

  final List<TripItineraryItem> items;
  final bool canManage;
  final VoidCallback onAdd;
  final ValueChanged<TripItineraryItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final byDay = <DateTime, List<TripItineraryItem>>{};
    for (final item in items) {
      final day = DateTime(item.scheduledAt.year, item.scheduledAt.month, item.scheduledAt.day);
      byDay.putIfAbsent(day, () => []).add(item);
    }
    final days = byDay.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Itinerary', style: Theme.of(context).textTheme.titleMedium),
            if (canManage)
              IconButton(icon: const Icon(LucideIcons.plus, size: 20), onPressed: onAdd),
          ],
        ),
        if (days.isEmpty)
          Text('No itinerary items yet.', style: Theme.of(context).textTheme.bodyMedium)
        else
          for (final entry in days.asMap().entries)
            _ItineraryDayGroup(
              dayNumber: entry.key + 1,
              date: entry.value,
              items: byDay[entry.value]!..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt)),
              isLast: entry.key == days.length - 1,
              canManage: canManage,
              onDelete: onDelete,
            ),
      ],
    );
  }
}

/// One day of the itinerary timeline — a numbered node connected by a
/// vertical line to the next day, with that day's items (title,
/// description, time) stacked inside a single card.
class _ItineraryDayGroup extends StatelessWidget {
  const _ItineraryDayGroup({
    required this.dayNumber,
    required this.date,
    required this.items,
    required this.isLast,
    required this.canManage,
    required this.onDelete,
  });

  final int dayNumber;
  final DateTime date;
  final List<TripItineraryItem> items;
  final bool isLast;
  final bool canManage;
  final ValueChanged<TripItineraryItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle),
                child: Text(
                  '$dayNumber',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: context.colors.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMM d').format(date).toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                    ),
                    const SizedBox(height: 6),
                    for (final item in items) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style:
                                      Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (item.description != null)
                                  Text(
                                    item.description!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: context.colors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('h:mm a').format(item.scheduledAt),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: context.colors.textSecondary),
                          ),
                          if (canManage) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => onDelete(item),
                              child: Icon(LucideIcons.trash2, size: 16, color: context.colors.error),
                            ),
                          ],
                        ],
                      ),
                      if (item != items.last) const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTab extends ConsumerWidget {
  const _ChecklistTab({
    required this.tripId,
    required this.canManage,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
  });

  final int tripId;
  final bool canManage;
  final VoidCallback onAdd;
  final ValueChanged<TaskItem> onToggle;
  final ValueChanged<TaskItem> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tripTasksProvider(tripId));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Checklist', style: Theme.of(context).textTheme.titleMedium),
            if (canManage) IconButton(icon: const Icon(LucideIcons.plus, size: 20), onPressed: onAdd),
          ],
        ),
        tasksAsync.when(
          data: (tasks) => tasks.isEmpty
              ? Text('No checklist items yet.', style: Theme.of(context).textTheme.bodyMedium)
              : Column(
                  children: [
                    for (final task in tasks)
                      TaskListTile(
                        task: task,
                        canManage: canManage,
                        onToggle: () => onToggle(task),
                        onDelete: canManage ? () => onDelete(task) : null,
                      ),
                  ],
                ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => const Text("Couldn't load the checklist."),
        ),
      ],
    );
  }
}

class _GroceriesTab extends ConsumerWidget {
  const _GroceriesTab({
    required this.tripId,
    required this.canManage,
    required this.onAdd,
    required this.onDelete,
  });

  final int tripId;
  final bool canManage;
  final VoidCallback onAdd;
  final ValueChanged<GroceryItem> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(tripGroceryItemsProvider(tripId));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Groceries', style: Theme.of(context).textTheme.titleMedium),
            if (canManage) IconButton(icon: const Icon(LucideIcons.plus, size: 20), onPressed: onAdd),
          ],
        ),
        itemsAsync.when(
          data: (items) => items.isEmpty
              ? Text('No grocery items yet.', style: Theme.of(context).textTheme.bodyMedium)
              : Column(
                  children: [
                    for (final item in items)
                      GroceryItemTile(
                        item: item,
                        canManage: canManage,
                        onToggled: () => ref.invalidate(tripGroceryItemsProvider(tripId)),
                        onEdit: () {},
                        onDelete: () => onDelete(item),
                      ),
                  ],
                ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => const Text("Couldn't load groceries."),
        ),
      ],
    );
  }
}

class _MemoriesTab extends StatelessWidget {
  const _MemoriesTab({
    required this.myMemberId,
    required this.myMemory,
    required this.otherMemories,
    required this.canManage,
    required this.onTapMine,
    required this.onDeleteMine,
    required this.onDeleteOther,
  });

  final int? myMemberId;
  final TripMemory? myMemory;
  final List<TripMemory> otherMemories;
  final bool canManage;
  final VoidCallback onTapMine;
  final VoidCallback? onDeleteMine;
  final ValueChanged<TripMemory> onDeleteOther;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text('Memories', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (myMemberId != null)
          _MyMemoryRow(memory: myMemory, onTap: onTapMine, onDelete: onDeleteMine),
        for (final memory in otherMemories)
          _MemoryTile(memory: memory, canDelete: canManage, onDelete: () => onDeleteOther(memory)),
      ],
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
