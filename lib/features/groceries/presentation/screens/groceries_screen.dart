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
import '../widgets/grocery_item_tile.dart';

/// A bottom-nav tab (like Calendar/Meals), not a pushed route -- no back
/// arrow.
class GroceriesScreen extends ConsumerStatefulWidget {
  const GroceriesScreen({super.key});

  @override
  ConsumerState<GroceriesScreen> createState() => _GroceriesScreenState();
}

class _GroceriesScreenState extends ConsumerState<GroceriesScreen> {
  String? _categoryFilter;

  Future<void> _openAddSheet() async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    final changed = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddEditGroceryItemSheet(householdId: household.id),
    );

    if (changed == true) ref.invalidate(currentHouseholdGroceryItemsProvider);
  }

  Future<void> _openEditSheet(GroceryItem item) async {
    final household = ref.read(currentHouseholdProvider);
    if (household == null) return;

    final changed = await showAppBottomSheet<bool>(
      context: context,
      builder: (context) => _AddEditGroceryItemSheet(householdId: household.id, existing: item),
    );

    if (changed == true) ref.invalidate(currentHouseholdGroceryItemsProvider);
  }

  Future<void> _deleteItem(GroceryItem item) async {
    try {
      await ref
          .read(groceryItemRepositoryProvider)
          .delete(householdId: item.householdId, itemId: item.id);
      ref.invalidate(currentHouseholdGroceryItemsProvider);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmClearPurchased(int householdId, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear purchased items?'),
        content: Text(
          'This removes all $count purchased ${count == 1 ? 'item' : 'items'} from the list. '
          "This can't be undone.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(groceryItemRepositoryProvider).clearPurchased(householdId: householdId);
      ref.invalidate(currentHouseholdGroceryItemsProvider);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(currentHouseholdGroceryItemsProvider);
    final household = ref.watch(currentHouseholdProvider);
    final canManage = household?.myRole == 'owner' || household?.myRole == 'adult';

    return Scaffold(
      body: SafeArea(
        child: itemsAsync.when(
          data: (items) {
            final unpurchasedCount = items.where((i) => !i.isPurchased).length;
            final filtered =
                _categoryFilter == null ? items : items.where((i) => i.category == _categoryFilter).toList();
            final unpurchased = filtered.where((i) => !i.isPurchased).toList();
            final purchased = filtered.where((i) => i.isPurchased).toList();

            return Column(
              children: [
                _GroceriesHeader(unpurchasedCount: unpurchasedCount, onAdd: _openAddSheet),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _CategoryChip(
                        label: 'All',
                        selected: _categoryFilter == null,
                        onTap: () => setState(() => _categoryFilter = null),
                      ),
                      const SizedBox(width: 8),
                      for (final category in kGroceryCategories) ...[
                        _CategoryChip(
                          label: category,
                          selected: _categoryFilter == category,
                          onTap: () => setState(() => _categoryFilter = category),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            'No groceries yet. Tap + to add something.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Nothing in this category.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              children: [
                                for (final item in unpurchased)
                                  GroceryItemTile(
                                    item: item,
                                    canManage: canManage,
                                    onToggled: () => ref.invalidate(currentHouseholdGroceryItemsProvider),
                                    onEdit: () => _openEditSheet(item),
                                    onDelete: () => _deleteItem(item),
                                  ),
                                if (purchased.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Purchased',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(color: context.colors.textSecondary),
                                      ),
                                      if (canManage && household != null)
                                        TextButton(
                                          onPressed: () =>
                                              _confirmClearPurchased(household.id, purchased.length),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text('Clear'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  for (final item in purchased)
                                    GroceryItemTile(
                                      item: item,
                                      canManage: canManage,
                                      onToggled: () => ref.invalidate(currentHouseholdGroceryItemsProvider),
                                      onEdit: () => _openEditSheet(item),
                                      onDelete: () => _deleteItem(item),
                                    ),
                                ],
                              ],
                            ),
                ),
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

class _GroceriesHeader extends StatelessWidget {
  const _GroceriesHeader({required this.unpurchasedCount, required this.onAdd});

  final int unpurchasedCount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Groceries', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(
                '$unpurchasedCount ${unpurchasedCount == 1 ? 'item' : 'items'} remaining',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.colors.textSecondary),
              ),
            ],
          ),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onAdd,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.colors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.plus, color: context.colors.primaryForeground),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
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


class _AddEditGroceryItemSheet extends ConsumerStatefulWidget {
  const _AddEditGroceryItemSheet({required this.householdId, this.existing});

  final int householdId;
  final GroceryItem? existing;

  @override
  ConsumerState<_AddEditGroceryItemSheet> createState() => _AddEditGroceryItemSheetState();
}

class _AddEditGroceryItemSheetState extends ConsumerState<_AddEditGroceryItemSheet> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _quantityController = TextEditingController(text: widget.existing?.quantity ?? '');
  late final _unitController = TextEditingController(text: widget.existing?.unit ?? '');
  late String? _category = widget.existing?.category;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
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
      final repository = ref.read(groceryItemRepositoryProvider);
      final quantity = _quantityController.text.trim().isEmpty ? null : _quantityController.text.trim();
      final unit = _unitController.text.trim().isEmpty ? null : _unitController.text.trim();

      if (_isEditing) {
        await repository.update(
          householdId: widget.householdId,
          itemId: widget.existing!.id,
          name: name,
          quantity: quantity,
          unit: unit,
          category: _category,
        );
      } else {
        await repository.create(
          householdId: widget.householdId,
          name: name,
          quantity: quantity,
          unit: unit,
          category: _category,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEditing ? 'Edit grocery item' : 'Add grocery item',
          style: Theme.of(context).textTheme.titleLarge,
        ),
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
        PrimaryButton(
          label: _isEditing ? 'Save changes' : 'Add item',
          isLoading: _isLoading,
          onPressed: _submit,
        ),
      ],
    );
  }
}
