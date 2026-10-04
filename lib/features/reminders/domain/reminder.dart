class Reminder {
  const Reminder({
    required this.category,
    required this.title,
    required this.message,
    this.tripId,
  });

  final String category;
  final String title;
  final String message;
  final int? tripId;

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      category: json['category'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      tripId: json['trip_id'] as int?,
    );
  }
}
