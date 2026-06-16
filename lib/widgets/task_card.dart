// lib/widgets/task_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TaskProvider>();
    final priorityColor = PriorityHelper.getColor(task.priority);

    return Dismissible(
      key: Key(task.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.danger.withOpacity(0.2)),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.danger, size: 26),
      ),
      confirmDismiss: (_) async {
        return await _confirmDelete(context);
      },
      onDismissed: (_) => provider.deleteTask(task.id),
      child: Hero(
        tag: 'task_hero_${task.id}',
        flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
          return Material(
            color: Colors.transparent,
            child: toHeroContext.widget,
          );
        },
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: task.isDone
                  ? AppColors.glassCard.withOpacity(0.3)
                  : AppColors.glassCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: task.isDone
                    ? Colors.white.withOpacity(0.03)
                    : Colors.white.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  // Beautiful Custom Checkbox
                  GestureDetector(
                    onTap: () => provider.toggleTask(task.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: task.isDone
                            ? AppColors.primaryGradient
                            : null,
                        border: task.isDone
                            ? null
                            : Border.all(
                                color: priorityColor.withOpacity(0.8),
                                width: 2,
                              ),
                        boxShadow: task.isDone
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: task.isDone
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: task.isDone
                              ? AppTheme.taskTitleDone
                              : AppTheme.taskTitle.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.notes != null && task.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.notes!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Type icon (soft colored based on type)
                            Icon(
                              task.type == TaskType.task
                                  ? Icons.assignment_outlined
                                  : Icons.calendar_today_outlined,
                              size: 13,
                              color: TypeHelper.getColor(task.type),
                            ),
                            const SizedBox(width: 5),
                            // Date
                            Text(
                              DateHelper.formatDate(task.deadline),
                              style: AppTheme.timeLabel.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            if (task.time != null &&
                                task.time!.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              const Icon(Icons.access_time_rounded,
                                  size: 13, color: AppColors.textHint),
                              const SizedBox(width: 3),
                              Text(
                                task.time!,
                                style: AppTheme.timeLabel.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (!task.isDone) ...[
                              const Spacer(),
                              // Glowing Gradient Priority Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: PriorityHelper.getGradient(task.priority),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: priorityColor.withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  PriorityHelper.getLabel(task.priority),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (task.emailNotifEnabled) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.email_outlined,
                        size: 16, color: AppColors.info),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Tugas?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Yakin ingin menghapus "${task.title}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
