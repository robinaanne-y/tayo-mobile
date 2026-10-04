import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_color_tokens.dart';
import '../../domain/grocery_item.dart';
import '../providers/grocery_providers.dart';

/// Shared between the Groceries screen and a trip's Groceries section -- a
/// trip-scoped item is still just a GroceryItem, so the row rendering is
/// the same either way rather than duplicated. [onToggled] lets each
/// screen decide which provider(s) to invalidate after a purchase toggle
/// (the full household list, a trip-scoped filter, or both).
class GroceryItemTile extends ConsumerWidget {
  const GroceryItemTile({
    super.key,
    required this.item,
    required this.canManage,
    required this.onToggled,
    required this.onEdit,
    required this.onDelete,
  });

  final GroceryItem item;
  final bool canManage;
  final VoidCallback onToggled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Future<void> _toggle(WidgetRef ref) async {
    final repository = ref.read(groceryItemRepositoryProvider);
    if (item.isPurchased) {
      await repository.unpurchase(householdId: item.householdId, itemId: item.id);
    } else {
      await repository.purchase(householdId: item.householdId, itemId: item.id);
    }
    onToggled();
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
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
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
        ],
      ),
    );

    // Edit/remove are Owner/Adult only, and reachable only by swiping --
    // no always-visible delete icon. A non-manager's tile is plain, with
    // no swipe affordance at all.
    if (!canManage) {
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: card);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey(item.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.5,
          children: [
            SlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: context.colors.primary.withValues(alpha: 0.12),
              foregroundColor: context.colors.primary,
              icon: LucideIcons.pencil,
              label: 'Edit',
              borderRadius: BorderRadius.circular(16),
            ),
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: context.colors.error.withValues(alpha: 0.12),
              foregroundColor: context.colors.error,
              icon: LucideIcons.trash2,
              label: 'Delete',
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
        child: card,
      ),
    );
  }
}
