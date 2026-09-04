enum HouseholdRole {
  owner,
  adult,
  minor,
  child;

  static HouseholdRole? fromValue(String? value) {
    return HouseholdRole.values
        .where((role) => role.name == value)
        .firstOrNull;
  }

  String get label => switch (this) {
        HouseholdRole.owner => 'Owner',
        HouseholdRole.adult => 'Adult',
        HouseholdRole.minor => 'Minor',
        HouseholdRole.child => 'Child',
      };
}

class Member {
  const Member({
    required this.id,
    required this.name,
    this.birthDate,
    required this.isPlaceholder,
    this.role,
  });

  final int id;
  final String name;
  final DateTime? birthDate;
  final bool isPlaceholder;
  final HouseholdRole? role;

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as int,
      name: json['name'] as String,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      isPlaceholder: json['is_placeholder'] as bool? ?? false,
      role: HouseholdRole.fromValue(json['role'] as String?),
    );
  }
}
