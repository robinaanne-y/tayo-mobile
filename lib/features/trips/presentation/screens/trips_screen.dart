import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/config/env.dart';
import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../../members/domain/member.dart';
import '../../../members/presentation/providers/member_providers.dart';
import '../../domain/trip.dart';
import '../providers/trip_providers.dart';
import 'past_trips_screen.dart';
import 'trip_detail_screen.dart';

/// Reached by pushing (from Home's "Trips" tile and the Upcoming Trip
/// section), not a bottom-nav tab — the nav bar is already full at 5/5.
class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  Future<void> _openAddSheet() async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    final changed = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => AddEditTripSheet(householdId: household.id),
    );

    if (changed == true) ref.invalidate(currentHouseholdTripsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(currentHouseholdTripsProvider);
    final pastTripsAsync = ref.watch(currentHouseholdPastTripsProvider);
    final household = ref.watch(currentHouseholdProvider);
    final canManage = household?.myRole == 'owner' || household?.myRole == 'adult';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        actions: [
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _AddTripButton(onPressed: _openAddSheet),
            ),
        ],
      ),
      body: SafeArea(
        child: tripsAsync.when(
          data: (trips) {
            final upcoming = trips.where((t) => t.isUpcoming).toList()
              ..sort((a, b) => a.startAt.compareTo(b.startAt));
            final pastTrips = pastTripsAsync.valueOrNull ?? const [];

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                Text(
                  'FAMILY ADVENTURES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Trips & memories',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  "Plan what's next. Keep the good days close.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Coming up',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            upcoming.isEmpty
                                ? 'Nothing on the family calendar yet'
                                : '${upcoming.length} trip${upcoming.length == 1 ? '' : 's'} on the family calendar',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (upcoming.isNotEmpty && upcoming.first.daysUntil != null && upcoming.first.daysUntil! > 0) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.colors.primarySoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Next in ${upcoming.first.daysUntil} day${upcoming.first.daysUntil == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: context.colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                if (upcoming.isEmpty)
                  _EmptyTripsCard(canManage: canManage, onAdd: _openAddSheet)
                else ...[
                  _UpcomingHeroCard(trip: upcoming.first),
                  if (upcoming.length > 1) ...[
                    const SizedBox(height: 12),
                    for (final trip in upcoming.skip(1)) ...[
                      _UpcomingCompactRow(trip: trip),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
                if (pastTrips.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _PastTripsSectionHeader(
                    count: pastTrips.length,
                    onViewAll: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PastTripsScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _PastTripsPreviewGrid(trips: pastTrips.take(4).toList()),
                ],
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

String _durationLabel(Trip trip) {
  if (trip.endAt == null) return '1 day';
  final days = trip.endAt!.difference(trip.startAt).inDays + 1;
  return '$days day${days == 1 ? '' : 's'}';
}

/// Circular filled "+" action replacing the old plain AppBar icon button,
/// matching the redesign's floating add-trip affordance.
class _AddTripButton extends StatelessWidget {
  const _AddTripButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(LucideIcons.plus, color: context.colors.primaryForeground, size: 20),
        ),
      ),
    );
  }
}

class _EmptyTripsCard extends StatelessWidget {
  const _EmptyTripsCard({required this.canManage, required this.onAdd});

  final bool canManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.palmtree, size: 28, color: context.colors.primary),
          const SizedBox(height: 10),
          Text(
            canManage ? 'No upcoming trips. Tap + to plan one.' : 'No upcoming trips yet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// The nearest upcoming trip, shown large: cover photo with a date "sticker"
/// and a duration/destination overlay pill, then title, location, and a
/// dated "View plan" link through to the trip's detail screen.
class _UpcomingHeroCard extends StatelessWidget {
  const _UpcomingHeroCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.12),
                    image: trip.thumbnailUrl != null
                        ? DecorationImage(
                            image: NetworkImage('${Env.mediaBaseUrl}${trip.thumbnailUrl}'),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: trip.thumbnailUrl == null
                      ? Center(child: Icon(LucideIcons.plane, size: 36, color: context.colors.primary))
                      : null,
                ),
                Positioned(top: 12, left: 12, child: _DateSticker(date: trip.startAt)),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _OverlayPill(
                    label: [_durationLabel(trip), if (trip.destination != null) trip.destination!].join(' · '),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (trip.destination != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(LucideIcons.mapPin, size: 14, color: context.colors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          trip.destination!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Divider(height: 1, color: context.colors.border),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.calendar, size: 16, color: context.colors.textSecondary),
                          const SizedBox(width: 6),
                          Text(_dateRangeLabel(trip), style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View plan',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Icon(LucideIcons.arrowRight, size: 14, color: context.colors.primary),
                        ],
                      ),
                    ],
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

/// White "sticker" date badge over the hero photo — month and day, fixed
/// light styling regardless of theme since it reads as a physical tag.
class _DateSticker extends StatelessWidget {
  const _DateSticker({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(
            DateFormat('MMM').format(date).toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black54),
          ),
          Text(
            DateFormat('d').format(date),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Compact row for upcoming trips beyond the nearest one — status badge,
/// title, and dates, same tap target as the hero card.
class _UpcomingCompactRow extends StatelessWidget {
  const _UpcomingCompactRow({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                image: trip.thumbnailUrl != null
                    ? DecorationImage(
                        image: NetworkImage('${Env.mediaBaseUrl}${trip.thumbnailUrl}'),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: trip.thumbnailUrl == null ? Icon(LucideIcons.plane, color: context.colors.primary) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusBadge(status: trip.status),
                  const SizedBox(height: 4),
                  Text(
                    trip.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [_dateRangeLabel(trip), if (trip.destination != null) trip.destination!].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: context.colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TripStatus status;

  Color _colorFor(BuildContext context) => switch (status) {
        TripStatus.planning => context.colors.coral,
        TripStatus.confirmed => context.colors.primary,
        TripStatus.completed => context.colors.success,
        TripStatus.cancelled => context.colors.textDisabled,
      };

  @override
  Widget build(BuildContext context) {
    return Text(
      _statusLabel(status).toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: _colorFor(context),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
    );
  }
}

class _PastTripsSectionHeader extends StatelessWidget {
  const _PastTripsSectionHeader({required this.count, required this.onViewAll});

  final int count;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Past trips',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Favorite places, all together',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onViewAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count trip${count == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Icon(LucideIcons.chevronRight, size: 16, color: context.colors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Non-scrollable teaser grid (first few thumbnails only) — "View all"
/// above opens the full Past Trips gallery for the rest.
class _PastTripsPreviewGrid extends StatelessWidget {
  const _PastTripsPreviewGrid({required this.trips});

  final List<Trip> trips;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: trips.length,
      itemBuilder: (context, index) => _PastTripPreviewTile(trip: trips[index]),
    );
  }
}

class _PastTripPreviewTile extends StatelessWidget {
  const _PastTripPreviewTile({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          image: trip.thumbnailUrl != null
              ? DecorationImage(
                  image: NetworkImage('${Env.mediaBaseUrl}${trip.thumbnailUrl}'),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: trip.thumbnailUrl == null
            ? Center(child: Icon(LucideIcons.images, color: context.colors.primary))
            : null,
      ),
    );
  }
}

class AddEditTripSheet extends ConsumerStatefulWidget {
  const AddEditTripSheet({super.key, required this.householdId, this.existing});

  final int householdId;
  final Trip? existing;

  @override
  ConsumerState<AddEditTripSheet> createState() => _AddEditTripSheetState();
}

class _AddEditTripSheetState extends ConsumerState<AddEditTripSheet> {
  late final _titleController = TextEditingController(text: widget.existing?.title ?? '');
  late final _destinationController =
      TextEditingController(text: widget.existing?.destination ?? '');
  late final _notesController = TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime _startAt = widget.existing?.startAt ?? DateTime.now();
  late DateTime? _endAt = widget.existing?.endAt;
  late TripStatus _status = widget.existing?.status ?? TripStatus.planning;
  final Set<int> _participantIds = {};

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _participantIds.addAll(widget.existing?.participants.map((p) => p.id) ?? const []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
    );
    if (date != null) {
      setState(() {
        _startAt = date;
        if (_endAt != null && _endAt!.isBefore(_startAt)) _endAt = _startAt;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endAt ?? _startAt,
      firstDate: _startAt,
      lastDate: DateTime.now().add(const Duration(days: 1825)),
    );
    if (date != null) setState(() => _endAt = date);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(tripRepositoryProvider);
      final destination =
          _destinationController.text.trim().isEmpty ? null : _destinationController.text.trim();
      final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

      if (_isEditing) {
        await repository.update(
          householdId: widget.householdId,
          tripId: widget.existing!.id,
          title: title,
          destination: destination,
          startAt: _startAt,
          endAt: _endAt,
          notes: notes,
          status: _status,
          participantMemberIds: _participantIds.toList(),
        );
      } else {
        await repository.create(
          householdId: widget.householdId,
          title: title,
          destination: destination,
          startAt: _startAt,
          endAt: _endAt,
          notes: notes,
          participantMemberIds: _participantIds.toList(),
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
            _isEditing ? 'Edit trip' : 'Plan a trip',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],
          AppTextField(label: 'Title', controller: _titleController),
          const SizedBox(height: 16),
          AppTextField(label: 'Destination (optional)', controller: _destinationController),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickStartDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Starts'),
                    child: Text(dateFormat.format(_startAt)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickEndDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Ends (optional)'),
                    child: Text(_endAt != null ? dateFormat.format(_endAt!) : '—'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(label: 'Notes (optional)', controller: _notesController),
          if (_isEditing) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<TripStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final status in TripStatus.values)
                  DropdownMenuItem(value: status, child: Text(_statusLabel(status))),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
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
                  _TripParticipantChip(
                    member: entry.value,
                    colorIndex: entry.key,
                    selected: _participantIds.contains(entry.value.id),
                    onTap: () => setState(() {
                      if (!_participantIds.remove(entry.value.id)) {
                        _participantIds.add(entry.value.id);
                      }
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: _isEditing ? 'Save changes' : 'Plan trip',
            isLoading: _isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

String _statusLabel(TripStatus status) => switch (status) {
      TripStatus.planning => 'Planning',
      TripStatus.confirmed => 'Confirmed',
      TripStatus.completed => 'Completed',
      TripStatus.cancelled => 'Cancelled',
    };

class _TripParticipantChip extends StatelessWidget {
  const _TripParticipantChip({
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
