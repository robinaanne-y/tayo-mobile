enum EventVisibility {
  private,
  household;

  String get value => name;

  static EventVisibility fromValue(String value) {
    return EventVisibility.values.firstWhere((v) => v.value == value);
  }
}

class Event {
  const Event({
    required this.id,
    required this.householdId,
    required this.creatorMemberId,
    required this.creatorName,
    required this.title,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.visibility,
  });

  final int id;
  final int householdId;
  final int creatorMemberId;
  final String creatorName;
  final String title;
  final String? description;
  final DateTime startAt;
  final DateTime endAt;
  final EventVisibility visibility;

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as int,
      householdId: json['household_id'] as int,
      creatorMemberId: json['creator_member_id'] as int,
      creatorName: json['creator_name'] as String? ?? '',
      title: json['title'] as String,
      description: json['description'] as String?,
      startAt: DateTime.parse(json['start_at'] as String).toLocal(),
      endAt: DateTime.parse(json['end_at'] as String).toLocal(),
      visibility: EventVisibility.fromValue(json['visibility'] as String),
    );
  }
}
