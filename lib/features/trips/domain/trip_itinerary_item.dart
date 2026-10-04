class TripItineraryItem {
  const TripItineraryItem({
    required this.id,
    required this.tripId,
    required this.title,
    required this.description,
    required this.scheduledAt,
    required this.createdByMemberId,
    required this.createdByName,
    required this.createdAt,
  });

  final int id;
  final int tripId;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final int createdByMemberId;
  final String? createdByName;
  final DateTime createdAt;

  factory TripItineraryItem.fromJson(Map<String, dynamic> json) {
    return TripItineraryItem(
      id: json['id'] as int,
      tripId: json['trip_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
      createdByMemberId: json['created_by_member_id'] as int,
      createdByName: json['created_by_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
