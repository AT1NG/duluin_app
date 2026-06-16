// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/weekly_calendar.dart';
import '../widgets/task_card.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/app_logo.dart';
import '../widgets/progress_chart.dart';
import 'progress_screen.dart';
import 'task_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openAddTask(BuildContext context, TaskType type) {
    final provider = context.read<TaskProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: TaskFormSheet(
          initialType: type,
          initialDate: provider.selectedDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // App header
                SliverToBoxAdapter(
                  child: _buildHeader(context),
                ),
                // Calendar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const WeeklyCalendar(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Selected date label + progress
                SliverToBoxAdapter(
                  child: _buildDateProgress(context),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // Task list
                SliverToBoxAdapter(
                  child: _buildTaskList(context),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),

            // FAB
            Positioned(
              bottom: 96,
              right: 20,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: RawMaterialButton(
                  shape: const CircleBorder(),
                  onPressed: () => _openAddTask(context, TaskType.task),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          const DuluinHeader(),
          const Spacer(),
          // Progress shortcut
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProgressScreen())),
            child: Consumer<TaskProvider>(
              builder: (_, provider, __) => CircularProgressWidget(
                percent: provider.progressPercent,
                total: provider.totalTasks,
                done: provider.completedTasks,
                size: 56,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateProgress(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (_, provider, __) {
        final total = provider.totalForDate;
        final done = provider.completedForDate;
        final date = provider.selectedDate;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateHelper.isSameDay(date, DateTime.now())
                        ? 'Hari Ini'
                        : DateHelper.formatDate(date),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '$done dari $total tugas selesai',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${(provider.progressForDate * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskList(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (_, provider, __) {
        final tasks = provider.rankedTasksForSelectedDate;
        final agendas = provider.agendasForSelectedDate;

        if (tasks.isEmpty && agendas.isEmpty) {
          return _buildEmpty(context, provider);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tasks.isNotEmpty) ...[
                _sectionHeader('Tugas', Icons.assignment_outlined,
                    count: tasks.length),
                const SizedBox(height: 8),
                ...tasks.map((task) => TaskCard(
                      task: task,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: provider,
                            child: TaskDetailScreen(task: task),
                          ),
                        ),
                      ),
                    )),
              ],
              if (agendas.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sectionHeader('Agenda', Icons.calendar_today_outlined,
                    count: agendas.length),
                const SizedBox(height: 8),
                ...agendas.map((task) => TaskCard(
                      task: task,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: provider,
                            child: TaskDetailScreen(task: task),
                          ),
                        ),
                      ),
                    )),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String label, IconData icon, {int? count}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmpty(BuildContext context, TaskProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.task_alt_rounded,
            size: 64,
            color: AppColors.textHint.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada rencana hari ini.',
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + untuk menambahkan tugas atau agenda',
            style: TextStyle(color: AppColors.textHint, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _quickAddButton(
                context,
                'Tambah Tugas',
                Icons.add_task_rounded,
                () => _openAddTask(context, TaskType.task),
              ),
              const SizedBox(width: 12),
              _quickAddButton(
                context,
                'Tambah Agenda',
                Icons.event_rounded,
                () => _openAddTask(context, TaskType.agenda),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickAddButton(
      BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.glassCard,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primaryLight),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
