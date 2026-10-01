import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../domain/grocery_item.dart';
import '../providers/grocery_providers.dart';

/// A bottom-nav tab (like Calendar), not a pushed route -- no back arrow,
/// same custom-header-row pattern as `CalendarScreen`'s own top-level
/// Scaffold rather than a Material `AppBar`.
class GroceriesScreen extends ConsumerWidget {
  const GroceriesScreen({super.key});

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    final added = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddEditGroceryItemSheet(householdId: household.id),
    );

    if (added == true) ref.invalidate(currentHouseholdGroceryItemsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(currentHouseholdGroceryItemsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(context, ref),
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.primaryForeground,
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Groceries', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
            Expanded(
              child: itemsAsync.when(
                data: (items) {
                  final unpurchased = items.where((i) => !i.isPurchased).toList();
                  final purchased = items.where((i) => i.isPurchased).toList();

                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No groceries yet. Tap + to add something.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      for (final item in unpurchased)
                        _GroceryItemTile(item: item, householdId: item.householdId),
                      if (purchased.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Purchased',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: context.colors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        for (final item in purchased)
                          _GroceryItemTile(item: item, householdId: item.householdId),
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
          ],
        ),
      ),
    );
  }
}

class _GroceryItemTile extends ConsumerWidget {
  const _GroceryItemTile({required this.item, required this.householdId});

  final GroceryItem item;
  final int householdId;

  Future<void> _toggle(WidgetRef ref) async {
    final repository = ref.read(groceryItemRepositoryProvider);
    if (item.isPurchased) {
      await repository.unpurchase(householdId: householdId, itemId: item.id);
    } else {
      await repository.purchase(householdId: householdId, itemId: item.id);
    }
    ref.invalidate(currentHouseholdGroceryItemsProvider);
  }

  Future<void> _delete(WidgetRef ref) async {
    await ref.read(groceryItemRepositoryProvider).delete(householdId: householdId, itemId: item.id);
    ref.invalidate(currentHouseholdGroceryItemsProvider);
  }

  String get _subtitle {
    final parts = [
      if (item.quantity != null && item.quantity!.isNotEmpty)
        [item.quantity, item.unit].where((p) => p != null && p.isNotEmpty).join(' '),
      if (item.category != null && item.category!.isNotEmpty) item.category,
      if (item.addedByName != null) 'Added by ${item.addedByName}',
    ].whereType<String>().where((p) => p.isNotEmpty).toList();

    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _toggle(ref),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                item.isPurchased ? LucideIcons.checkCircle2 : LucideIcons.circle,
                color: item.isPurchased ? context.colors.primary : context.colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        decoration: item.isPurchased ? TextDecoration.lineThrough : null,
                        color: item.isPurchased ? context.colors.textSecondary : null,
                      ),
                ),
                if (_subtitle.isNotEmpty)
                  Text(_subtitle, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _delete(ref),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(LucideIcons.x, size: 18, color: context.colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddEditGroceryItemSheet extends ConsumerStatefulWidget {
  const _AddEditGroceryItemSheet({required this.householdId});

  final int householdId;

  @override
  ConsumerState<_AddEditGroceryItemSheet> createState() => _AddEditGroceryItemSheetState();
}

class _AddEditGroceryItemSheetState extends ConsumerState<_AddEditGroceryItemSheet> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _categoryController.dispose();
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
            quantity: _quantityController.text.trim().isEmpty ? null : _quantityController.text.trim(),
            unit: _unitController.text.trim().isEmpty ? null : _unitController.text.trim(),
            category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
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
        Row(
          children: [
            Expanded(child: AppTextField(label: 'Quantity (optional)', controller: _quantityController)),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(label: 'Unit (optional)', controller: _unitController)),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(label: 'Category (optional)', controller: _categoryController),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Add item', isLoading: _isLoading, onPressed: _submit),
      ],
    );
  }
}
