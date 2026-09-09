import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../domain/member.dart';
import '../providers/member_providers.dart';

class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  Future<List<Member>>? _membersFuture;
  Member? _selected;

  int? get _householdId {
    final households = ref.read(authControllerProvider).user?.households;
    return households != null && households.isNotEmpty ? households.first.id : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _membersFuture ??= _loadMembers();
  }

  Future<List<Member>> _loadMembers() {
    final householdId = _householdId;
    if (householdId == null) return Future.value(const []);
    return ref.read(memberRepositoryProvider).forHousehold(householdId);
  }

  void _reload() {
    setState(() {
      _membersFuture = _loadMembers();
      _selected = null;
    });
  }

  Future<void> _openAddMemberSheet() async {
    final householdId = _householdId;
    if (householdId == null) return;

    final added = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddMemberSheet(householdId: householdId),
    );

    if (added == true) _reload();
  }

  Future<void> _openInviteSheet() async {
    final householdId = _householdId;
    if (householdId == null) return;

    await showAppBottomSheet<void>(
      context: context,
      builder: (context) => _InviteSheet(householdId: householdId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return _MemberDetail(
        member: _selected!,
        householdId: _householdId,
        onBack: () => setState(() => _selected = null),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family'),
        actions: [
          IconButton(
            icon: const Icon(Icons.link_rounded),
            tooltip: 'Invite to household',
            onPressed: _openInviteSheet,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            onPressed: _openAddMemberSheet,
          ),
        ],
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
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final member = members[index];
              return Card(
                child: InkWell(
                  onTap: () => setState(() => _selected = member),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        MemberAvatar(name: member.name, colorIndex: index, size: 52),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(member.name,
                                  style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 2),
                              Text(
                                member.role?.label ?? '',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              StatusPill(
                                label: member.isPlaceholder
                                    ? 'No account yet'
                                    : 'Account connected',
                                background: member.isPlaceholder
                                    ? AppColors.border
                                    : AppColors.primary.withValues(alpha: 0.15),
                                foreground: member.isPlaceholder
                                    ? AppColors.textSecondary
                                    : AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.border),
                      ],
                    ),
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

class _MemberDetail extends ConsumerWidget {
  const _MemberDetail({required this.member, required this.householdId, required this.onBack});

  final Member member;
  final int? householdId;
  final VoidCallback onBack;

  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    final id = householdId;
    if (id == null) return;

    try {
      final activation = await ref.read(memberRepositoryProvider).createActivationLink(
            householdId: id,
            memberId: member.id,
          );
      if (context.mounted) {
        await showAppBottomSheet<void>(
          context: context,
          builder: (context) => _ShareLinkSheet(
            title: 'Activation link for ${member.name}',
            link: activation.link,
          ),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onBack,
        ),
        title: Text(member.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: MemberAvatar(name: member.name, colorIndex: 0, size: 76)),
          const SizedBox(height: 20),
          _DetailRow(label: 'Role', value: member.role?.label ?? '—'),
          _DetailRow(
            label: 'Account',
            value: member.isPlaceholder ? 'No account yet' : 'Connected',
          ),
          if (member.isPlaceholder) ...[
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Send activation link',
              onPressed: () => _activate(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
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
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add a member', style: Theme.of(context).textTheme.titleLarge),
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
    );
  }
}

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({required this.householdId});

  final int householdId;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  HouseholdRole _role = HouseholdRole.adult;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final invitation = await ref.read(invitationRepositoryProvider).create(
            householdId: widget.householdId,
            role: _role,
          );
      if (mounted) {
        Navigator.of(context).pop();
        await showAppBottomSheet<void>(
          context: context,
          builder: (context) => _ShareLinkSheet(
            title: 'Invite link (${_role.label})',
            link: invitation.link,
          ),
        );
      }
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
        Text('Invite to household', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Anyone with this link can join as the role you choose.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
        ],
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
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Generate link',
          isLoading: _isLoading,
          onPressed: _generate,
        ),
      ],
    );
  }
}

/// Shown after generating an invite or activation link — lets the owner
/// copy or share it through the platform share sheet.
class _ShareLinkSheet extends StatelessWidget {
  const _ShareLinkSheet({required this.title, required this.link});

  final String title;
  final String link;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Expires in 7 days, and can only be used once.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(link, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: QrImageView(
              data: link,
              size: 160,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(color: AppColors.textPrimary),
              dataModuleStyle: const QrDataModuleStyle(color: AppColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Or have them scan this code from the app',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Link copied.')));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Share',
                onPressed: () => Share.share(link),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
