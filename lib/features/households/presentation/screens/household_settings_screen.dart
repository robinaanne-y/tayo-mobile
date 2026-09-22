import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/household.dart';
import '../household_visuals.dart';
import '../providers/household_providers.dart';

class HouseholdSettingsScreen extends ConsumerStatefulWidget {
  const HouseholdSettingsScreen({super.key, required this.household});

  final Household household;

  @override
  ConsumerState<HouseholdSettingsScreen> createState() =>
      _HouseholdSettingsScreenState();
}

class _HouseholdSettingsScreenState
    extends ConsumerState<HouseholdSettingsScreen> {
  late final TextEditingController _nameController;
  late Color _color;
  late String _emoji;

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isOwner => widget.household.myRole == 'owner';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.household.name);
    _color = householdColorFromHex(widget.household.color);
    _emoji = widget.household.emoji ?? kHouseholdEmojis.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(householdRepositoryProvider).update(
            householdId: widget.household.id,
            name: _nameController.text.trim(),
            color: householdColorToHex(_color),
            emoji: _emoji,
          );
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Household settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!_isOwner) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Only the household Owner can change these settings.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (_errorMessage != null) ...[
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
          ],
          Center(
            child: Container(
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
          ),
          const SizedBox(height: 24),
          AppTextField(
            label: 'Household name',
            controller: _nameController,
            enabled: _isOwner,
          ),
          const SizedBox(height: 20),
          Text('Accent color', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: kHouseholdColors.map((c) {
              final selected = c.toARGB32() == _color.toARGB32();
              return GestureDetector(
                onTap: _isOwner ? () => setState(() => _color = c) : null,
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
            children: kHouseholdEmojis.map((e) {
              final selected = e == _emoji;
              return GestureDetector(
                onTap: _isOwner ? () => setState(() => _emoji = e) : null,
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
          if (_isOwner) ...[
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save changes',
              isLoading: _isLoading,
              onPressed: _submit,
            ),
          ],
        ],
      ),
    );
  }
}
