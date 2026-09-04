import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/member.dart';
import '../providers/member_providers.dart';

class HouseholdMembersScreen extends ConsumerStatefulWidget {
  const HouseholdMembersScreen({super.key, required this.householdId});

  final int householdId;

  @override
  ConsumerState<HouseholdMembersScreen> createState() =>
      _HouseholdMembersScreenState();
}

class _HouseholdMembersScreenState extends ConsumerState<HouseholdMembersScreen> {
  late Future<List<Member>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembers();
  }

  Future<List<Member>> _loadMembers() {
    return ref.read(memberRepositoryProvider).forHousehold(widget.householdId);
  }

  void _reload() {
    setState(() => _membersFuture = _loadMembers());
  }

  Future<void> _openAddMemberSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddMemberSheet(householdId: widget.householdId),
    );

    if (added == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Household members')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddMemberSheet,
        child: const Icon(Icons.person_add_rounded),
      ),
      body: FutureBuilder<List<Member>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error is ApiException
                    ? (snapshot.error as ApiException).message
                    : 'Something went wrong. Please try again.',
              ),
            );
          }

          final members = snapshot.data ?? const [];
          if (members.isEmpty) {
            return const Center(child: Text('No members yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final member = members[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.memberColor(index),
                    child: Text(member.name.isNotEmpty ? member.name[0] : '?'),
                  ),
                  title: Text(member.name),
                  subtitle: Text(
                    [
                      member.role?.label,
                      member.isPlaceholder ? 'No account yet' : null,
                    ].whereType<String>().join(' · '),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AddMemberSheet extends ConsumerStatefulWidget {
  const _AddMemberSheet({required this.householdId});

  final int householdId;

  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  HouseholdRole _role = HouseholdRole.child;
  DateTime? _birthDate;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 8),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(memberRepositoryProvider).create(
            householdId: widget.householdId,
            name: _nameController.text.trim(),
            role: _role,
            birthDate: _birthDate,
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
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a member', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],
            AppTextField(
              label: 'Name',
              controller: _nameController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<HouseholdRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: HouseholdRole.values
                  .map((role) => DropdownMenuItem(value: role, child: Text(role.label)))
                  .toList(),
              onChanged: (value) => setState(() => _role = value ?? _role),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_birthDate == null
                  ? 'Birth date (optional)'
                  : '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.calendar_today_rounded),
              onTap: _pickBirthDate,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Add member',
              isLoading: _isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
