class Household {
  const Household({
    required this.id,
    required this.name,
    this.color,
    this.emoji,
    this.myRole,
    this.memberCount,
    this.createdAt,
    this.mealApproverMemberId,
    this.mealApproverName,
  });

  final int id;
  final String name;
  final String? color;
  final String? emoji;
  final String? myRole;
  final int? memberCount;
  final DateTime? createdAt;

  /// The one member designated to manage the meal plan and approve/
  /// decline meal requests, when set -- null means no delegation: any
  /// Owner/Adult manages. See `MealsScreen`'s `_canManageMeals`.
  final int? mealApproverMemberId;
  final String? mealApproverName;

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as int,
      name: json['name'] as String,
      color: json['color'] as String?,
      emoji: json['emoji'] as String?,
      myRole: json['my_role'] as String?,
      memberCount: json['member_count'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      mealApproverMemberId: json['meal_approver_member_id'] as int?,
      mealApproverName: json['meal_approver_name'] as String?,
    );
  }
}
