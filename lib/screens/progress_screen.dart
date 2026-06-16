// lib/screens/progress_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../models/task_model.dart';
import '../widgets/progress_chart.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF131124), Color(0xFF0A0914)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Progres & Statistik',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            Consumer<TaskProvider>(
              builder: (_, provider, __) => provider.completedTasks > 0
                  ? IconButton(
                      icon: const Icon(Icons.cleaning_services_outlined,
                          color: AppColors.textHint),
                      tooltip: 'Hapus tugas selesai',
                      onPressed: () => _confirmClear(context, provider),
                    )
                  : const SizedBox(),
            ),
          ],
        ),
        body: Consumer<TaskProvider>(
          builder: (_, provider, __) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), // Added padding for floating nav
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall stats row
                  _buildStatsRow(provider),
                  const SizedBox(height: 16),

                  // Overall Progress Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.glassCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Progres Keseluruhan',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '${(provider.progressPercent * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: AppColors.primaryLight,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LinearPercentIndicator(
                          lineHeight: 10.0,
                          percent: provider.progressPercent,
                          backgroundColor: AppColors.glassBg,
                          linearGradient: AppColors.primaryGradient,
                          barRadius: const Radius.circular(5),
                          padding: EdgeInsets.zero,
                          animation: true,
                          animationDuration: 1000,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${provider.completedTasks} dari ${provider.totalTasks} tugas selesai',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bar chart
                  const ProgressChart(),
                  const SizedBox(height: 16),

                  // Priority breakdown
                  _buildPrioritySection(provider),
                  const SizedBox(height: 16),

                  // All tasks list
                  _buildAllTasksList(provider),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsRow(TaskProvider provider) {
    return Row(
      children: [
        Expanded(
            child: _statCard('Total', '${provider.totalTasks}',
                Icons.list_alt_rounded, AppColors.info)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard('Selesai', '${provider.completedTasks}',
                Icons.check_circle_rounded, AppColors.success)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard('Terlambat', '${provider.overdueTasks}',
                Icons.warning_amber_rounded, AppColors.danger)),
      ],
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.glassCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrioritySection(TaskProvider provider) {
    final high = provider.mendesakCount;
    final medium = provider.sedangCount;
    final low = provider.santaiCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.glassCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribusi Prioritas (Aktif)',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          _priorityBar('Mendesak', high, AppColors.priorityHigh),
          const SizedBox(height: 10),
          _priorityBar('Sedang', medium, AppColors.priorityMedium),
          const SizedBox(height: 10),
          _priorityBar('Santai', low, AppColors.priorityLow),
        ],
      ),
    );
  }

  Widget _priorityBar(String label, int count, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.glassBg,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (count > 0)
                FractionallySizedBox(
                  widthFactor: (count / 10).clamp(0.05, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: label == 'Mendesak'
                          ? AppColors.priorityHighGradient
                          : label == 'Sedang'
                              ? AppColors.priorityMediumGradient
                              : AppColors.priorityLowGradient,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 24,
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildAllTasksList(TaskProvider provider) {
    final all = provider.tasks
        .where((t) => t.type == TaskType.task)
        .toList()
      ..sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return a.priorityScore.compareTo(b.priorityScore);
      });

    if (all.isEmpty) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.glassCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Semua Tugas',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: const Text(
                  'Smart Ranked ⚡',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...all.map((task) => _compactTaskRow(task)),
        ],
      ),
    );
  }

  Widget _compactTaskRow(TaskModel task) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              gradient: task.isDone ? null : PriorityHelper.getGradient(task.priority),
              color: task.isDone ? AppColors.textHint : null,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: task.isDone
                        ? AppColors.textHint
                        : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration:
                        task.isDone ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateHelper.formatDate(task.deadline),
                  style: const TextStyle(
                      color: AppColors.textHint, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (task.isDone)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 20)
          else if (task.isOverdue)
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.danger, size: 20),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, TaskProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Bersihkan Tugas?',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'Hapus semua tugas yang sudah selesai?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textHint, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearCompleted();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
