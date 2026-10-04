/// A fixed vocabulary matching the API's ReminderCategory enum — plain
/// strings, not a Dart enum, since the preferences list/toggle UI just
/// needs the category's wire value and a human label, not any
/// category-specific behavior on the client.
const Map<String, String> kReminderCategoryLabels = {
  'meal_planning': 'Meal planning',
  'grocery': 'Grocery list',
  'trip_prep': 'Trip preparation',
};

class NotificationPreference {
  const NotificationPreference({required this.category, required this.enabled});

  final String category;
  final bool enabled;

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      category: json['category'] as String,
      enabled: json['enabled'] as bool,
    );
  }
}
