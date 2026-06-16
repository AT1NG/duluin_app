// lib/utils/helpers.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task_model.dart';
import '../theme/app_theme.dart';

class DateHelper {
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM').format(date);
  }

  static String formatDateFull(DateTime date) {
    try {
      return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return DateFormat('EEEE, d MMMM yyyy').format(date);
    }
  }

  static String formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    return time;
  }

  static String dayAbbr(DateTime date) {
    return DateFormat('E').format(date).substring(0, 3);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String relativeDeadline(DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now).inDays;
    if (diff < 0) return 'Terlambat ${diff.abs()} hari';
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Besok';
    return '$diff hari lagi';
  }
}

class PriorityHelper {
  static Color getColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AppColors.priorityHigh;
      case TaskPriority.medium:
        return AppColors.priorityMedium;
      case TaskPriority.low:
        return AppColors.priorityLow;
    }
  }

  static LinearGradient getGradient(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AppColors.priorityHighGradient;
      case TaskPriority.medium:
        return AppColors.priorityMediumGradient;
      case TaskPriority.low:
        return AppColors.priorityLowGradient;
    }
  }

  static String getLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 'Mendesak';
      case TaskPriority.medium:
        return 'Sedang';
      case TaskPriority.low:
        return 'Santai';
    }
  }

  static IconData getIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Icons.local_fire_department_rounded;
      case TaskPriority.medium:
        return Icons.schedule_rounded;
      case TaskPriority.low:
        return Icons.check_circle_outline_rounded;
    }
  }
}

class TypeHelper {
  static LinearGradient getGradient(TaskType type) {
    switch (type) {
      case TaskType.task:
        return AppColors.taskGradient;
      case TaskType.agenda:
        return AppColors.agendaGradient;
    }
  }

  static Color getColor(TaskType type) {
    switch (type) {
      case TaskType.task:
        return AppColors.primaryLight;
      case TaskType.agenda:
        return AppColors.info;
    }
  }
}

class EmailHelper {
  /// Launch mailto for email reminder
  static Future<void> sendEmailReminder({
    required String toEmail,
    required String taskTitle,
    required DateTime deadline,
    String? time,
  }) async {
    final subject = Uri.encodeComponent('[Duluin] Pengingat: $taskTitle');
    final deadlineStr = DateHelper.formatDate(deadline);
    final timeStr = time != null ? ' pukul $time' : '';
    final body = Uri.encodeComponent(
      'Halo!\n\nIni adalah pengingat dari Duluin.\n\n'
      'Tugas: $taskTitle\n'
      'Deadline: $deadlineStr$timeStr\n\n'
      'Jangan sampai terlewat ya! 💪\n\n'
      '- Tim Duluin',
    );
    final uri = Uri.parse('mailto:$toEmail?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
