class TaskItem {
  const TaskItem({
    required this.id,
    required this.householdId,
    required this.title,
    required this.description,
    required this.dueAt,
    this.tripId,
    required this.assignedMemberId,
    required this.assigneeName,
    required this.createdByMemberId,
    required this.createdByName,
    required this.completedAt,
    required this.completedByName,
    required this.isRecurring,
    this.recurrenceSummary,
  });

  final int id;
  final int householdId;
  final String title;
  final String? description;
  final DateTime? dueAt;
  final int? tripId;
  final int? assignedMemberId;
  final String? assigneeName;
  final int createdByMemberId;
  final String? createdByName;
  final DateTime? completedAt;
  final String? completedByName;
  final bool isRecurring;
  final String? recurrenceSummary;

  bool get isCompleted => completedAt != null;

  bool get isOverdue {
    if (isCompleted || dueAt == null) return false;
    final today = DateTime.now();
    final dueDate = DateTime(dueAt!.year, dueAt!.month, dueAt!.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    return dueDate.isBefore(todayDate);
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as int,
      householdId: json['household_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      dueAt: json['due_at'] != null ? DateTime.parse(json['due_at'] as String) : null,
      tripId: json['trip_id'] as int?,
      assignedMemberId: json['assigned_member_id'] as int?,
      assigneeName: json['assignee_name'] as String?,
      createdByMemberId: json['created_by_member_id'] as int,
      createdByName: json['created_by_name'] as String?,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String).toLocal()
          : null,
      completedByName: json['completed_by_name'] as String?,
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurrenceSummary: json['recurrence_summary'] as String?,
    );
  }
}
