/// A fixed vocabulary rather than free text, so the same values can drive
/// both the add/edit sheet's dropdown and the list's filter chips. Plain
/// strings, not an enum -- the API's `category` column is already a free
/// string with no server-side validation, so there's no mapping to do.
const List<String> kGroceryCategories = [
  'Produce',
  'Meat',
  'Dairy',
  'Pantry',
  'Toiletries',
  'Bakery',
  'Frozen',
  'Beverages',
  'Household',
  'Other',
];

class GroceryItem {
  const GroceryItem({
    required this.id,
    required this.householdId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.tripId,
    required this.addedByName,
    required this.purchasedAt,
    required this.purchasedByName,
  });

  final int id;
  final int householdId;
  final String name;
  final String? quantity;
  final String? unit;
  final String? category;
  final int? tripId;
  final String? addedByName;
  final DateTime? purchasedAt;
  final String? purchasedByName;

  bool get isPurchased => purchasedAt != null;

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id'] as int,
      householdId: json['household_id'] as int,
      name: json['name'] as String,
      quantity: json['quantity'] as String?,
      unit: json['unit'] as String?,
      category: json['category'] as String?,
      tripId: json['trip_id'] as int?,
      addedByName: json['added_by_name'] as String?,
      purchasedAt: json['purchased_at'] != null
          ? DateTime.parse(json['purchased_at'] as String).toLocal()
          : null,
      purchasedByName: json['purchased_by_name'] as String?,
    );
  }
}
