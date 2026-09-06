import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../households/presentation/screens/create_household_screen.dart';
import '../../domain/member.dart';
import '../providers/member_providers.dart';

class InviteMemberScreen extends ConsumerStatefulWidget {
  const InviteMemberScreen({super.key, this.preview});

  final HouseholdVisualPreview? preview;

  @override
  ConsumerState<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends ConsumerState<InviteMemberScreen> {
  final List<Member> _added = [];

  int? get _householdId {
    final households = ref.read(authControllerProvider).user?.households;
    return households != null && households.isNotEmpty ? households.first.id : null;
  }

  Future<void> _openAddSheet() async {
    final householdId = _householdId;
    if (householdId == null) return;

    final added = await showAppBottomSheet<Member>(
      context: context,
      builder: (context) => _AddMemberForm(householdId: householdId),
    );

    if (added != null) setState(() => _added.add(added));
  }

  @override
  Widget build(BuildContext context) {
    final household = ref.watch(authControllerProvider).user?.households.firstOrNull;
    final color = widget.preview?.color ?? AppColors.primary;
    final emoji = widget.preview?.emoji ?? '🏡';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Setting up',
                              style: Theme.of(context).textTheme.bodySmall),
                          Text(
                            household?.name ?? '',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Add your family members',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    "Add everyone who'll use the app. You can also create "
                    'placeholder profiles for babies and young children.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                children: [
                  for (var i = 0; i < _added.length; i++) ...[
                    Card(
                      child: ListTile(
                        leading: MemberAvatar(name: _added[i].name, colorIndex: i),
                        title: Text(_added[i].name),
                        subtitle: Text(_added[i].role?.label ?? ''),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  InkWell(
                    onTap: _openAddSheet,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1.5,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.add_rounded, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Add family member',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  PrimaryButton(
                    label: _added.isEmpty
                        ? 'Skip for now'
                        : 'Continue with ${_added.length + 1} members',
                    onPressed: () => context.go('/home'),
                  ),
                  if (_added.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'You can invite family members later from the Family tab',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMemberForm extends ConsumerStatefulWidget {
  const _AddMemberForm({required this.householdId});

  final int householdId;

  @override
  ConsumerState<_AddMemberForm> createState() => _AddMemberFormState();
}

class _AddMemberFormState extends ConsumerState<_AddMemberForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  HouseholdRole _role = HouseholdRole.adult;
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
      final member = await ref.read(memberRepositoryProvider).create(
            householdId: widget.householdId,
            name: _nameController.text.trim(),
            role: _role,
            birthDate: _birthDate,
          );
      if (mounted) Navigator.of(context).pop(member);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add family member', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
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
          Text('Role', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: HouseholdRole.values
                .where((r) => r != HouseholdRole.owner)
                .map((role) {
              final selected = role == _role;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _role = role),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      role.label,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_role == HouseholdRole.child) ...[
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_birthDate == null
                  ? 'Birthday (optional)'
                  : '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.calendar_today_rounded),
              onTap: _pickBirthDate,
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Add member',
            isLoading: _isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
