import '../../households/domain/household.dart';

enum EventVisibility {
  private('private'),
  household('household'),
  selectedHouseholds('selected_households'),
  allMemberHouseholds('all_member_households');

  const EventVisibility(this.value);

  final String value;

  static EventVisibility fromValue(String value) {
    return EventVisibility.values.firstWhere((v) => v.value == value);
  }
}

/// The recurrence pattern a new event can be created with. Immutable once
/// the event exists — there is no "edit the pattern" flow, only "edit this
/// occurrence" or "edit this and following occurrences" (see
/// [Event.isRecurring]).
enum RecurrenceFrequency {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly');

  const RecurrenceFrequency(this.value);

  final String value;
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
    required this.location,
    required this.startAt,
    required this.endAt,
    required this.visibility,
    required this.participants,
    required this.sharedHouseholds,
    required this.isRecurring,
    this.recurrenceSummary,
  });

  final int id;
  final int householdId;
  final int creatorMemberId;
  final String creatorName;
  final String title;
  final String? description;
  final String? location;
  final DateTime startAt;
  final DateTime endAt;
  final EventVisibility visibility;
  final List<EventParticipant> participants;
  final List<Household> sharedHouseholds;
  final bool isRecurring;
  final String? recurrenceSummary;

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as int,
      householdId: json['household_id'] as int,
      creatorMemberId: json['creator_member_id'] as int,
      creatorName: json['creator_name'] as String? ?? '',
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      startAt: DateTime.parse(json['start_at'] as String).toLocal(),
      endAt: DateTime.parse(json['end_at'] as String).toLocal(),
      visibility: EventVisibility.fromValue(json['visibility'] as String),
      participants: (json['participants'] as List<dynamic>? ?? [])
          .map((p) => EventParticipant.fromJson(p as Map<String, dynamic>))
          .toList(),
      sharedHouseholds: (json['shared_households'] as List<dynamic>? ?? [])
          .map((h) => Household.fromJson(h as Map<String, dynamic>))
          .toList(),
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurrenceSummary: json['recurrence_summary'] as String?,
    );
  }
}
