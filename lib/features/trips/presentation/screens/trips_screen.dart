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
    final household = ref.watch(currentHouseholdProvider);
    final canManage = household?.myRole == 'owner' || household?.myRole == 'adult';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.images),
            tooltip: 'Past trips',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PastTripsScreen()),
            ),
          ),
          if (canManage)
            IconButton(
              icon: const Icon(LucideIcons.plus),
              onPressed: _openAddSheet,
            ),
        ],
      ),
      body: SafeArea(
        child: tripsAsync.when(
          data: (trips) {
            final upcoming = trips.where((t) => !t.isPast).toList()
              ..sort((a, b) => a.startAt.compareTo(b.startAt));

            if (upcoming.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No upcoming trips. Tap + to plan one.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final trip in upcoming) _TripRow(trip: trip),
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

class _TripRow extends StatelessWidget {
  const _TripRow({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  image: trip.thumbnailUrl != null
                      ? DecorationImage(image: NetworkImage(trip.thumbnailUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: trip.thumbnailUrl == null
                    ? Icon(LucideIcons.plane, color: context.colors.primary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.title, style: Theme.of(context).textTheme.bodyMedium),
                    Text(
                      [
                        DateFormat('MMM d, y').format(trip.startAt),
                        if (trip.destination != null) trip.destination,
                        if (trip.daysUntil != null && trip.daysUntil! > 0)
                          'in ${trip.daysUntil} day${trip.daysUntil == 1 ? '' : 's'}',
                      ].whereType<String>().join(' · '),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: context.colors.textSecondary),
            ],
          ),
        ),
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
