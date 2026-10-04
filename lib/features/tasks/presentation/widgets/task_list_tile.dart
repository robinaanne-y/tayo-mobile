import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_color_tokens.dart';
import '../../domain/task_item.dart';

/// Shared between the Tasks screen and a trip's Checklist section -- a
/// trip-scoped task is still just a Task, so the row rendering is the same
/// either way rather than duplicated.
class TaskListTile extends StatelessWidget {
  const TaskListTile({
    super.key,
    required this.task,
    required this.canManage,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  final TaskItem task;
  final bool canManage;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  String get _subtitle {
    final parts = [
      if (task.dueAt != null) DateFormat('MMM d').format(task.dueAt!),
      if (task.assigneeName != null) task.assigneeName,
      if (task.isRecurring && task.recurrenceSummary != null) task.recurrenceSummary,
    ].whereType<String>().toList();

    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                task.isCompleted ? LucideIcons.checkCircle2 : LucideIcons.circle,
                color: task.isCompleted
                    ? context.colors.primary
                    : task.isOverdue
                        ? context.colors.error
                        : context.colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        color: task.isCompleted ? context.colors.textSecondary : null,
                      ),
                ),
                if (_subtitle.isNotEmpty)
                  Text(
                    _subtitle,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: task.isOverdue && !task.isCompleted ? context.colors.error : null,
                        ),
                  ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(LucideIcons.pencil, size: 18),
              onPressed: onEdit,
            ),
          if (onDelete != null)
            IconButton(
              icon: Icon(LucideIcons.trash2, size: 18, color: context.colors.error),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
