import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/providers.dart';
import '../../../households/presentation/providers/household_providers.dart';
import '../../data/grocery_item_repository.dart';
import '../../domain/grocery_item.dart';

final groceryItemRepositoryProvider = Provider<GroceryItemRepository>((ref) {
  return GroceryItemRepository(ref.watch(apiClientProvider));
});

/// Every grocery item in the current household — the Groceries screen
/// splits this into unpurchased/purchased client-side rather than two
/// separate fetches, since a single household's list is small.
final currentHouseholdGroceryItemsProvider = FutureProvider<List<GroceryItem>>((ref) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  return ref.read(groceryItemRepositoryProvider).list(householdId: household.id);
});

/// A trip's grocery items -- the current household's list filtered by
/// trip_id server-side, not a separate concept (see TripDetailScreen).
final tripGroceryItemsProvider = FutureProvider.family<List<GroceryItem>, int>((ref, tripId) async {
  final household = ref.watch(currentHouseholdProvider);
  if (household == null) return const [];

  return ref.read(groceryItemRepositoryProvider).list(householdId: household.id, tripId: tripId);
});
