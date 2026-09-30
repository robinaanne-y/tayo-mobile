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
import '../../domain/permission_request.dart';
import '../providers/permission_request_providers.dart';

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

/// The full Requests list — a pushed route (not a bottom-nav tab), reached
/// from Home's header bell or the "Permissions" tile in `_MoreRow`.
class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  RequestStatus? _filter = RequestStatus.pending;

  Future<void> _openCreateSheet() async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    final saved = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddEditRequestSheet(householdId: household.id),
    );

    if (saved == true) {
      ref.invalidate(currentHouseholdRequestsProvider);
    }
  }

  Future<void> _openDetailSheet(PermissionRequest request) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _RequestDetailSheet(householdId: household.id, request: request),
    );

    // Unconditional, not gated on a "changed" return value: opening this
    // sheet for a resolved-but-unacknowledged request silently
    // acknowledges it (see _RequestDetailSheetState.initState), which the
    // caller has no explicit signal for -- refreshing regardless is the
    // simplest way to keep the bell badge/attention list in sync with that.
    ref.invalidate(currentHouseholdRequestsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(currentHouseholdRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Requests')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSheet,
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.primaryForeground,
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final option in [null, ...RequestStatus.values]) ...[
                      _FilterChip(
                        label: option == null ? 'All' : _statusLabel(option),
                        selected: _filter == option,
                        onTap: () => setState(() => _filter = option),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: requestsAsync.when(
                data: (requests) {
                  final visible =
                      _filter == null ? requests : requests.where((r) => r.status == _filter).toList();

                  if (visible.isEmpty) {
                    return Center(
                      child: Text(
                        'No requests here yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final request = visible[index];
                      return _RequestListTile(
                        request: request,
                        onTap: () => _openDetailSheet(request),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text(
                    error is ApiException ? error.message : 'Something went wrong.',
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

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

class _RequestListTile extends StatelessWidget {
  const _RequestListTile({required this.request, required this.onTap});

  final PermissionRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, h:mm a');

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
            [
              request.requesterName,
              if (request.hasTimeWindow) dateFormat.format(request.requestedStartAt!),
              _statusLabel(request.status),
            ].join(' · '),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ),
    );
  }
}

/// The requester's own can-act-on-it check ("adult, not the requester,
/// still pending") mirrors the API policy's `actOnRequest`, using the
/// same raw-string role comparison Home already uses (`myRole == 'owner'
/// || myRole == 'adult'`) rather than introducing a new role helper.
bool _canActOn(WidgetRef ref, PermissionRequest request) {
  final household = ref.watch(currentHouseholdProvider);
  final myMemberId = ref.watch(authControllerProvider).user?.member?.id;
  final canManage = household?.myRole == 'owner' || household?.myRole == 'adult';

  return canManage && myMemberId != request.requesterMemberId && request.status == RequestStatus.pending;
}

class _RequestDetailSheet extends ConsumerStatefulWidget {
  const _RequestDetailSheet({required this.householdId, required this.request});

  final int householdId;
  final PermissionRequest request;

  @override
  ConsumerState<_RequestDetailSheet> createState() => _RequestDetailSheetState();
}

class _RequestDetailSheetState extends ConsumerState<_RequestDetailSheet> {
  final _responseNoteController = TextEditingController();
  final _conditionController = TextEditingController();
  bool _createEvent = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Opening this sheet is what "reads" a resolved request for its
    // requester -- silently clear the notification the moment they see
    // it, the same way opening a notification elsewhere marks it read.
    // No loading state or error surface for this: it's a fire-and-forget
    // side effect of viewing, not a user-initiated action.
    if (widget.request.needsRequesterAttention) {
      ref.read(permissionRequestRepositoryProvider).acknowledge(
            householdId: widget.householdId,
            requestId: widget.request.id,
          );
    }
  }

  @override
  void dispose() {
    _responseNoteController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(permissionRequestRepositoryProvider).approve(
            householdId: widget.householdId,
            requestId: widget.request.id,
            responseNote: _responseNoteController.text.trim().isEmpty
                ? null
                : _responseNoteController.text.trim(),
            conditions: _conditionController.text.trim().isEmpty
                ? const []
                : [_conditionController.text.trim()],
            createEvent: _createEvent,
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
      await ref.read(permissionRequestRepositoryProvider).decline(
            householdId: widget.householdId,
            requestId: widget.request.id,
            responseNote: _responseNoteController.text.trim().isEmpty
                ? null
                : _responseNoteController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(permissionRequestRepositoryProvider).cancel(
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

  Future<void> _edit() async {
    final saved = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddEditRequestSheet(
        householdId: widget.householdId,
        existing: widget.request,
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final dateFormat = DateFormat('MMM d, y  •  h:mm a');
    final myMemberId = ref.watch(authControllerProvider).user?.member?.id;
    final canAct = _canActOn(ref, request);
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
        if (request.description != null && request.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(request.description!, style: Theme.of(context).textTheme.bodyMedium),
        ],
        if (request.hasTimeWindow) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(LucideIcons.calendarClock, size: 16, color: context.colors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${dateFormat.format(request.requestedStartAt!)} – '
                  '${DateFormat.jm().format(request.requestedEndAt!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
        if (request.conditions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Conditions', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          for (final condition in request.conditions)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(condition.description)),
                ],
              ),
            ),
        ],
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
          AppTextField(label: 'Add a condition (optional)', controller: _conditionController),
          if (request.hasTimeWindow) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _createEvent,
              onChanged: (value) => setState(() => _createEvent = value ?? false),
              title: const Text('Add to calendar when approved'),
            ),
          ],
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
          PrimaryButton(label: 'Edit request', isLoading: _isLoading, onPressed: _edit),
          const SizedBox(height: 8),
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

class _AddEditRequestSheet extends ConsumerStatefulWidget {
  const _AddEditRequestSheet({required this.householdId, this.existing});

  final int householdId;
  final PermissionRequest? existing;

  @override
  ConsumerState<_AddEditRequestSheet> createState() => _AddEditRequestSheetState();
}

class _AddEditRequestSheetState extends ConsumerState<_AddEditRequestSheet> {
  final _titleController = TextEditingController();
  final _typeController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startAt;
  DateTime? _endAt;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _typeController.text = existing.type ?? '';
      _descriptionController.text = existing.description ?? '';
      _startAt = existing.requestedStartAt;
      _endAt = existing.requestedEndAt;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _typeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickWindow() async {
    final base = _startAt ?? DateTime.now().add(const Duration(days: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;

    final startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (startTime == null || !mounted) return;

    final start = DateTime(date.year, date.month, date.day, startTime.hour, startTime.minute);

    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start.add(const Duration(hours: 1))),
    );
    if (endTime == null) return;

    final end = DateTime(date.year, date.month, date.day, endTime.hour, endTime.minute);

    setState(() {
      _startAt = start;
      _endAt = end.isAfter(start) ? end : start.add(const Duration(hours: 1));
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final type = _typeController.text.trim();
    final description = _descriptionController.text.trim();

    try {
      final repository = ref.read(permissionRequestRepositoryProvider);
      final existing = widget.existing;
      if (existing != null) {
        await repository.update(
          householdId: widget.householdId,
          requestId: existing.id,
          title: title,
          type: type.isEmpty ? null : type,
          description: description.isEmpty ? null : description,
          requestedStartAt: _startAt,
          requestedEndAt: _endAt,
        );
      } else {
        await repository.create(
          householdId: widget.householdId,
          title: title,
          type: type.isEmpty ? null : type,
          description: description.isEmpty ? null : description,
          requestedStartAt: _startAt,
          requestedEndAt: _endAt,
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
        Text(isEditing ? 'Edit request' : 'New request', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
        AppTextField(label: 'Title', controller: _titleController),
        const SizedBox(height: 16),
        AppTextField(label: 'Type (optional)', controller: _typeController),
        const SizedBox(height: 16),
        AppTextField(label: 'Description (optional)', controller: _descriptionController),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _pickWindow,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Time window (optional)'),
            child: Text(
              _startAt != null && _endAt != null
                  ? '${dateFormat.format(_startAt!)} – ${DateFormat.jm().format(_endAt!)}'
                  : 'Not time-specific',
            ),
          ),
        ),
        if (_startAt != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _startAt = null;
              _endAt = null;
            }),
            child: const Text('Remove time window'),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: isEditing ? 'Save changes' : 'Send request',
          isLoading: _isLoading,
          onPressed: _submit,
        ),
      ],
    );
  }
}
