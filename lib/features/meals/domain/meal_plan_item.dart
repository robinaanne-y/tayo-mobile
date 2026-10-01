enum MealSlot {
  breakfast('breakfast'),
  lunch('lunch'),
  dinner('dinner');

  const MealSlot(this.value);

  final String value;

  static MealSlot fromValue(String value) {
    return MealSlot.values.firstWhere((v) => v.value == value);
  }
}

class MealPlanItem {
  const MealPlanItem({
    required this.id,
    required this.householdId,
    required this.date,
    required this.slot,
    required this.title,
    required this.addedByName,
  });

  final int id;
  final int householdId;
  final DateTime date;
  final MealSlot slot;
  final String title;
  final String? addedByName;

  factory MealPlanItem.fromJson(Map<String, dynamic> json) {
    return MealPlanItem(
      id: json['id'] as int,
      householdId: json['household_id'] as int,
      date: DateTime.parse(json['date'] as String),
      slot: MealSlot.fromValue(json['slot'] as String),
      title: json['title'] as String,
      addedByName: json['added_by_name'] as String?,
    );
  }
}
