class Household {
  const Household({
    required this.id,
    required this.name,
    this.myRole,
    this.createdAt,
  });

  final int id;
  final String name;
  final String? myRole;
  final DateTime? createdAt;

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as int,
      name: json['name'] as String,
      myRole: json['my_role'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}
