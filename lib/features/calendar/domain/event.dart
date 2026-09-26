enum EventVisibility {
  private,
  household;

  String get value => name;

  static EventVisibility fromValue(String value) {
    return EventVisibility.values.firstWhere((v) => v.value == value);
  }
}

/// A household member tagged as involved in an event — a denormalized
/// slice of `Member`, not the full domain model, matching how `creatorName`
/// is already denormalized onto [Event] rather than nesting a full Member.
class EventParticipant {
  const EventParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  final int id;
  final String name;
  final String? avatarUrl;

  factory EventParticipant.fromJson(Map<String, dynamic> json) {
    return EventParticipant(
      id: json['id'] as int,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
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
    required this.participants,
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
  final List<EventParticipant> participants;

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
      participants: (json['participants'] as List<dynamic>? ?? [])
          .map((p) => EventParticipant.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}
