// lib/providers/task_provider.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../main.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';

class TaskProvider extends ChangeNotifier {
  static const String _storageKey = 'duluin_tasks';
  static const String _deviceKey = 'duluin_device_id';
  static const String _defaultWhatsappKey = 'duluin_default_whatsapp';
  static const String _defaultEmailKey = 'duluin_default_email';
  static const String _deletedTasksKey = 'duluin_deleted_task_ids';

  List<TaskModel> _tasks = [];
  final Set<String> _deletedTaskIds = {};
  String _deviceId = '';
  String _odooUrl = '';
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  
  String _defaultWhatsapp = '';
  String _defaultEmail = '';

  // Odoo API stats
  int _odooTotal = 0;
  int _odooCompleted = 0;
  int _odooOverdue = 0;
  int _odooMendesak = 0;
  int _odooSedang = 0;
  int _odooSantai = 0;

  // Getters
  List<TaskModel> get tasks => _tasks;
  String get deviceId => _deviceId;
  String get odooUrl => _odooUrl;
  bool get isLoading => _isLoading;
  DateTime get selectedDate => _selectedDate;
  String get defaultWhatsapp => _defaultWhatsapp;
  String get defaultEmail => _defaultEmail;

  // Stats
  int get totalTasks => _odooTotal > 0 ? _odooTotal : _tasks.where((t) => t.type == TaskType.task).length;
  int get completedTasks => _odooCompleted > 0 ? _odooCompleted : _tasks.where((t) => t.type == TaskType.task && t.isDone).length;
  int get overdueTasks => _odooOverdue > 0 ? _odooOverdue : _tasks.where((t) => t.isOverdue && t.type == TaskType.task).length;
  
  double get progressPercent => totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

  // Priority counts (either from Odoo stats or computed locally)
  int get mendesakCount => _odooMendesak > 0 ? _odooMendesak : _tasks.where((t) => t.priority == TaskPriority.high && !t.isDone).length;
  int get sedangCount => _odooSedang > 0 ? _odooSedang : _tasks.where((t) => t.priority == TaskPriority.medium && !t.isDone).length;
  int get santaiCount => _odooSantai > 0 ? _odooSantai : _tasks.where((t) => t.priority == TaskPriority.low && !t.isDone).length;

  /// Ranked tasks for selected date (incomplete first, sorted by priority score)
  List<TaskModel> get rankedTasksForSelectedDate {
    final date = _selectedDate;
    final filtered = _tasks.where((t) {
      return t.deadline.year == date.year &&
          t.deadline.month == date.month &&
          t.deadline.day == date.day &&
          t.type == TaskType.task;
    }).toList();

    filtered.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      return a.priorityScore.compareTo(b.priorityScore);
    });
    return filtered;
  }

  /// Agendas for selected date
  List<TaskModel> get agendasForSelectedDate {
    final date = _selectedDate;
    return _tasks.where((t) {
      return t.deadline.year == date.year &&
          t.deadline.month == date.month &&
          t.deadline.day == date.day &&
          t.type == TaskType.agenda;
    }).toList()
      ..sort((a, b) => a.priorityScore.compareTo(b.priorityScore));
  }

  /// All tasks for selected date (ranked)
  List<TaskModel> get allItemsForSelectedDate {
    final date = _selectedDate;
    final filtered = _tasks.where((t) {
      return t.deadline.year == date.year &&
          t.deadline.month == date.month &&
          t.deadline.day == date.day;
    }).toList();

    filtered.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      return a.priorityScore.compareTo(b.priorityScore);
    });
    return filtered;
  }

  // Stats for selected date
  int get totalForDate => rankedTasksForSelectedDate.length;
  int get completedForDate =>
      rankedTasksForSelectedDate.where((t) => t.isDone).length;
  double get progressForDate =>
      totalForDate == 0 ? 0.0 : completedForDate / totalForDate;

  // Days with tasks (for calendar dots)
  Set<String> get daysWithTasks {
    return _tasks.map((t) {
      final d = t.deadline;
      return '${d.year}-${d.month}-${d.day}';
    }).toSet();
  }

  bool hasTasks(DateTime date) {
    final key = '${date.year}-${date.month}-${date.day}';
    return daysWithTasks.contains(key);
  }

  // Weekly progress data for chart
  List<Map<String, dynamic>> get weeklyProgress {
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayTasks = _tasks.where((t) =>
          t.type == TaskType.task &&
          t.deadline.year == day.year &&
          t.deadline.month == day.month &&
          t.deadline.day == day.day);
      final total = dayTasks.length;
      final done = dayTasks.where((t) => t.isDone).length;
      result.add({
        'date': day,
        'total': total,
        'done': done,
        'percent': total == 0 ? 0.0 : done / total,
      });
    }
    return result;
  }

  // Automate Device ID using device_info_plus
  Future<String> _getUniqueDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String id = '';
    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        id = webInfo.userAgent ?? 'web_browser';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        id = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        id = iosInfo.identifierForVendor ?? 'ios_device';
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        id = winInfo.deviceId;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        id = macInfo.systemGUID ?? 'macos_device';
      } else {
        id = 'generic_device';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
      id = 'fallback_device_id';
    }
    // Clean and limit device ID
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '').trim();
  }

  // Initialize
  Future<void> init() async {
    // Defer the start of loading state update to prevent notifyListeners() from being called during the widget build phase
    await Future.delayed(Duration.zero);
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    // 0. Cloud Firebase initialization (no Odoo URL needed)
    _odooUrl = '';

    // 1. Get automated Device ID
    String? storedId = prefs.getString(_deviceKey);
    if (storedId == null || storedId.isEmpty) {
      storedId = await _getUniqueDeviceId();
      await prefs.setString(_deviceKey, storedId);
    }
    _deviceId = storedId;

    // Load default contact info
    _defaultWhatsapp = prefs.getString(_defaultWhatsappKey) ?? '';
    _defaultEmail = prefs.getString(_defaultEmailKey) ?? '';

    // Load deleted task IDs
    final deletedRaw = prefs.getStringList(_deletedTasksKey) ?? [];
    _deletedTaskIds.clear();
    _deletedTaskIds.addAll(deletedRaw);

    // 2. Load cached tasks first
    final raw = prefs.getStringList(_storageKey) ?? [];
    _tasks = raw
        .map((s) {
          try {
            return TaskModel.fromJsonString(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<TaskModel>()
        .toList();

    _isLoading = false;
    notifyListeners();

    // 3. Sync from Odoo API (run in background, do not block splash screen)
    syncWithOdoo(showLoading: false);
  }

  Future<void> syncWithOdoo({bool showLoading = false}) async {
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // Try to retry pending deletions on Firestore
      if (_deletedTaskIds.isNotEmpty) {
        final idsToRetry = List<String>.from(_deletedTaskIds);
        for (final idStr in idsToRetry) {
          try {
            final success = await ApiService.deleteTask(idStr);
            if (success) {
              _deletedTaskIds.remove(idStr);
            }
          } catch (e) {
            debugPrint('Retry delete failed for $idStr: $e');
          }
        }
        await _persistDeletedTaskIds();
      }

      // Fetch tasks from Firestore (segregated by deviceId)
      final odooTasks = await ApiService.fetchTasks(deviceId: _deviceId);
      
      // Start with our existing local tasks
      final Map<String, TaskModel> mergedTasks = {
        for (final t in _tasks) t.id.toString(): t
      };

      // Filter out any locally deleted tasks
      mergedTasks.removeWhere((id, _) => _deletedTaskIds.contains(id));

      // Add or update tasks from Firestore
      for (final remoteTask in odooTasks) {
        final remoteId = remoteTask.id.toString();
        if (_deletedTaskIds.contains(remoteId)) {
          continue;
        }
        
        // Always trust Firestore version for already synced items
        mergedTasks[remoteId] = remoteTask;
      }

      _tasks = mergedTasks.values.toList();
      await _persist();
      
      // Schedule notifications for all loaded active tasks
      for (final task in _tasks) {
        await _scheduleNotification(task);
      }

      // Fetch stats from Firestore (segregated by deviceId)
      final stats = await ApiService.fetchStats(deviceId: _deviceId);
      if (stats != null) {
        _odooTotal = stats['total_tugas'] ?? 0;
        _odooCompleted = stats['total_selesai'] ?? 0;
        _odooOverdue = stats['total_terlambat'] ?? 0;
        final dist = stats['priority_distribution'] ?? {};
        _odooMendesak = dist['mendesak'] ?? 0;
        _odooSedang = dist['sedang'] ?? 0;
        _odooSantai = dist['santai'] ?? 0;
      }
    } catch (e) {
      debugPrint('Firebase Sync failed: $e. Using local data.');
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _tasks.map((t) => t.toJsonString()).toList();
    await prefs.setStringList(_storageKey, raw);
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> updateDefaultContactInfo(String whatsapp, String email, {bool triggerNotify = true}) async {
    _defaultWhatsapp = whatsapp.trim();
    _defaultEmail = email.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultWhatsappKey, _defaultWhatsapp);
    await prefs.setString(_defaultEmailKey, _defaultEmail);
    if (triggerNotify) {
      notifyListeners();
    }
  }

  Future<void> addTask({
    required String name,
    String? description,
    required DateTime deadline,
    TaskPriority priority = TaskPriority.medium,
    TaskType type = TaskType.task,
    String whatsappNumber = '',
    String email = '',
    bool remind1d = false,
    bool remind1h = false,
  }) async {
    // Auto-save contact details as defaults if provided
    if (whatsappNumber.isNotEmpty || email.isNotEmpty) {
      await updateDefaultContactInfo(
        whatsappNumber.isNotEmpty ? whatsappNumber : _defaultWhatsapp,
        email.isNotEmpty ? email : _defaultEmail,
        triggerNotify: false,
      );
    }

    // Create model instance with a temp ID
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final task = TaskModel(
      id: tempId,
      name: name,
      description: description,
      deadline: deadline,
      priority: priority,
      type: type,
      whatsappNumber: whatsappNumber,
      email: email,
      remind1d: remind1d,
      remind1h: remind1h,
      deviceId: _deviceId,
    );

    // Optimistically add to local list and notify immediately
    _tasks.add(task);
    await _scheduleNotification(task);
    await _persist();
    notifyListeners();

    try {
      // Post to Firestore
      final createdTask = await ApiService.createTask(task);
      if (createdTask != null) {
        // Replace temp task with server-confirmed task
        final idx = _tasks.indexWhere((t) => t.id == tempId);
        if (idx != -1) {
          _tasks[idx] = createdTask;
          await _scheduleNotification(createdTask);
          await _persist();
          notifyListeners();
        } else {
          // The task was deleted locally before creation finished!
          // Since the document was created on the server, we must delete it on the server now!
          await ApiService.deleteTask(createdTask.id);
        }
      }
    } catch (e) {
      debugPrint('createTask failed: $e. Saving locally.');
    }

    // Trigger full sync silently to get updated statistics
    syncWithOdoo(showLoading: false);
  }

  Future<void> toggleTask(dynamic id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final currentTask = _tasks[idx];
      final newIsDone = !currentTask.isDone;
      final updated = currentTask.copyWith(isDone: newIsDone);
      _tasks[idx] = updated;
      
      notifyListeners();
      await _persist();
      
      // Update local notification status
      await _scheduleNotification(updated);

      // Attempt to sync state to Firestore in background
      final newStateStr = newIsDone ? 'selesai' : 'aktif';
      try {
        await ApiService.updateTaskState(id, newStateStr);
      } catch (e) {
        debugPrint('Failed to update task state on Firestore: $e');
      }

      // Sync stats silently
      syncWithOdoo(showLoading: false);
    }
  }

  Future<void> _persistDeletedTaskIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_deletedTasksKey, _deletedTaskIds.toList());
  }

  Future<void> deleteTask(dynamic id) async {
    final idStr = id.toString();
    _deletedTaskIds.add(idStr);
    await _persistDeletedTaskIds();

    _tasks.removeWhere((t) => t.id == id);
    await _persist();
    notifyListeners();
    
    // Cancel local notifications
    final baseId = _getNotificationId(id);
    await flutterLocalNotificationsPlugin.cancel(baseId);
    await flutterLocalNotificationsPlugin.cancel(baseId + 1000000);
    await flutterLocalNotificationsPlugin.cancel(baseId + 2000000);
    
    try {
      final success = await ApiService.deleteTask(id);
      if (success) {
        _deletedTaskIds.remove(idStr);
        await _persistDeletedTaskIds();
      }
    } catch (e) {
      debugPrint('Failed to delete task in Firestore: $e');
    }

    // Sync stats silently in background
    syncWithOdoo(showLoading: false);
  }

  Future<void> updateTask(TaskModel updated) async {
    final idx = _tasks.indexWhere((t) => t.id == updated.id);
    if (idx != -1) {
      _tasks[idx] = updated;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> clearCompleted() async {
    _tasks.removeWhere((t) => t.isDone);
    await _persist();
    notifyListeners();
  }

  Future<void> updateOdooUrl(String url) async {
    // Deprecated for Firebase migration
    notifyListeners();
  }

  int _getNotificationId(dynamic taskId) {
    if (taskId is int) return taskId;
    return taskId.toString().hashCode & 0x7FFFFFFF; // Mask to fit standard 32-bit int
  }

  Future<void> _scheduleNotification(TaskModel task) async {
    final baseId = _getNotificationId(task.id);
    final id1h = baseId;
    final id1d = baseId + 1000000;
    final idDeadline = baseId + 2000000;

    // Cancel existing scheduled notifications for this task first
    await flutterLocalNotificationsPlugin.cancel(id1h);
    await flutterLocalNotificationsPlugin.cancel(id1d);
    await flutterLocalNotificationsPlugin.cancel(idDeadline);

    if (task.isDone) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'duluin_reminders',
      'Pengingat Tugas Duluin',
      channelDescription: 'Saluran notifikasi untuk pengingat tugas H-1 Jam/Hari',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    final now = DateTime.now();

    // 1. Schedule H-1 Day Reminder
    if (task.remind1d) {
      final triggerTime1d = task.deadline.subtract(const Duration(days: 1));
      if (triggerTime1d.isAfter(now)) {
        final tzDateTime1d = tz.TZDateTime.from(triggerTime1d, tz.local);
        try {
          await flutterLocalNotificationsPlugin.zonedSchedule(
            id1d,
            '🔔 Pengingat H-1 Hari: ${task.name}',
            'Jangan lupa untuk menyelesaikan tugas ini! 💪',
            tzDateTime1d,
            platformDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          debugPrint('Scheduled 1d notif for: ${task.name} at $tzDateTime1d');
        } catch (e) {
          debugPrint('Error scheduling 1d notif: $e');
        }
      }
    }

    // 2. Schedule H-1 Hour Reminder
    if (task.remind1h) {
      final triggerTime1h = task.deadline.subtract(const Duration(hours: 1));
      if (triggerTime1h.isAfter(now)) {
        final tzDateTime1h = tz.TZDateTime.from(triggerTime1h, tz.local);
        try {
          await flutterLocalNotificationsPlugin.zonedSchedule(
            id1h,
            '🚨 Pengingat H-1 Jam: ${task.name}',
            'Waktu sisa 1 jam lagi! Ayo bereskan! ⚡',
            tzDateTime1h,
            platformDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          debugPrint('Scheduled 1h notif for: ${task.name} at $tzDateTime1h');
        } catch (e) {
          debugPrint('Error scheduling 1h notif: $e');
        }
      }
    }

    // 3. Schedule Exact Deadline Reminder
    if (task.deadline.isAfter(now)) {
      final tzDateTimeDeadline = tz.TZDateTime.from(task.deadline, tz.local);
      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          idDeadline,
          '⏰ Batas Waktu Tugas: ${task.name}',
          'Waktu untuk menyelesaikan tugas ini telah berakhir! 🏁',
          tzDateTimeDeadline,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint('Scheduled deadline notif for: ${task.name} at $tzDateTimeDeadline');
      } catch (e) {
        debugPrint('Error scheduling deadline notif: $e');
      }
    }
  }
}
