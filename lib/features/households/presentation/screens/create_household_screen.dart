import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../providers/household_providers.dart';

/// Cosmetic, ephemeral picks from step 2 — not persisted anywhere, since the
/// backend `Household` model has no color/emoji field yet. Passed forward
/// only to prefill the Invite Member screen's header preview.
class HouseholdVisualPreview {
  const HouseholdVisualPreview({required this.color, required this.emoji});

  final Color color;
  final String emoji;
}

const _kHouseholdColors = [
  AppColors.primary,
  AppColors.skyBlue,
  AppColors.accent,
  AppColors.lavender,
  AppColors.softYellow,
];

const _kHouseholdEmojis = ['🏡', '🏠', '🌿', '⭐', '🐾', '🍀', '🌞'];

class CreateHouseholdScreen extends ConsumerStatefulWidget {
  const CreateHouseholdScreen({super.key});

  @override
  ConsumerState<CreateHouseholdScreen> createState() =>
      _CreateHouseholdScreenState();
}

class _CreateHouseholdScreenState extends ConsumerState<CreateHouseholdScreen> {
  final _nameController = TextEditingController();

  int _step = 1;
  Color _color = _kHouseholdColors.first;
  String _emoji = _kHouseholdEmojis.first;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    if (_step == 1) {
      if (_nameController.text.trim().isEmpty) return;
      setState(() => _step = 2);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final household = await ref
          .read(householdRepositoryProvider)
          .create(_nameController.text.trim());
      await ref.read(authControllerProvider.notifier).refreshUser();
      // Make the newly created household the active one — otherwise, when
      // this isn't the user's first household, currentHouseholdProvider
      // would keep pointing at whichever one was already selected.
      ref.read(selectedHouseholdIdProvider.notifier).state = household.id;
      if (mounted) {
        context.go(
          '/invite-members',
          extra: HouseholdVisualPreview(color: _color, emoji: _emoji),
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
    final name = _nameController.text.trim();
    // Mandatory during first-time onboarding (no way out — you must create
    // a household to proceed). Reached later from the household switcher
    // to create an *additional* one, it's optional, so offer a close button.
    final canLeave = ref.watch(authControllerProvider).hasHousehold;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canLeave)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => context.go('/home'),
                  ),
                ),
              Row(
                children: [1, 2].map((s) {
                  final active = s <= _step;
                  return Expanded(
                    child: Container(
                      height: 6,
                      margin: EdgeInsets.only(right: s == 1 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text('Step $_step of 2', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    if (_step == 1) ..._buildStepOne(context) else ..._buildStepTwo(context, name),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: _step == 1 ? 'Continue' : 'Create household',
                isLoading: _isLoading,
                onPressed: _step == 1 && name.isEmpty ? null : _proceed,
              ),
              if (_step == 2) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _step = 1),
                    child: const Text('Back'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStepOne(BuildContext context) {
    return [
      Text('Name your household', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      Text(
        'This is what your family will see. You can always change it later.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 24),
      _buildPreview(_nameController.text.trim().isEmpty
          ? 'Your Household'
          : _nameController.text.trim()),
      const SizedBox(height: 20),
      AppTextField(
        label: 'Household name',
        controller: _nameController,
      ),
    ];
  }

  List<Widget> _buildStepTwo(BuildContext context, String name) {
    return [
      Text('Make it yours', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      Text.rich(
        TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            const TextSpan(text: 'Pick a color and emoji for '),
            TextSpan(
              text: name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _buildPreview(name),
      const SizedBox(height: 20),
      Text('Accent color', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _kHouseholdColors.map((c) {
          final selected = c == _color;
          return GestureDetector(
            onTap: () => setState(() => _color = c),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: AppColors.background, width: 3)
                    : null,
                boxShadow: selected
                    ? [BoxShadow(color: c, blurRadius: 0, spreadRadius: 2)]
                    : null,
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                  : null,
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),
      Text('Household icon', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _kHouseholdEmojis.map((e) {
          final selected = e == _emoji;
          return GestureDetector(
            onTap: () => setState(() => _emoji = e),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _color.withValues(alpha: 0.15) : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? _color : AppColors.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Text(e, style: const TextStyle(fontSize: 20)),
            ),
          );
        }).toList(),
      ),
    ];
  }

  Widget _buildPreview(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _color.withValues(alpha: 0.35), width: 3),
            ),
            child: Text(_emoji, style: const TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: 12),
          Text(name, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
