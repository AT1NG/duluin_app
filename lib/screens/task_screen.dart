// lib/screens/task_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../models/task_model.dart';
import '../widgets/task_card.dart';
import '../widgets/task_form_sheet.dart';
import 'task_detail_screen.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddTask(BuildContext context) {
    final provider = context.read<TaskProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: TaskFormSheet(
          initialType: TaskType.task,
          initialDate: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Semua Tugas', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textHint,
              tabs: const [
                Tab(child: Text('Aktif', style: TextStyle(fontWeight: FontWeight.bold))),
                Tab(child: Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold))),
                Tab(child: Text('Semua', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
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
            onPressed: () => _openAddTask(context),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
      body: Consumer<TaskProvider>(
        builder: (_, provider, __) {
          final all = provider.tasks
              .where((t) => t.type == TaskType.task)
              .toList()
            ..sort((a, b) {
              if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
              return a.priorityScore.compareTo(b.priorityScore);
            });

          final active = all.where((t) => !t.isDone).toList();
          final done = all.where((t) => t.isDone).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _taskList(context, provider, active, 'Tidak ada tugas aktif'),
              _taskList(context, provider, done, 'Belum ada tugas selesai'),
              _taskList(context, provider, all, 'Belum ada tugas'),
            ],
          );
        },
      ),
    );
  }

  Widget _taskList(BuildContext context, TaskProvider provider,
      List<TaskModel> tasks, String emptyMsg) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded,
                size: 56, color: AppColors.textHint.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(emptyMsg,
                style: const TextStyle(color: AppColors.textHint, fontSize: 14)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 4),
              Text(
                'Smart Priority Ranking — ${tasks.length} tugas',
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: tasks.length,
            itemBuilder: (_, i) => TaskCard(
              task: tasks[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: provider,
                    child: TaskDetailScreen(task: tasks[i]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
