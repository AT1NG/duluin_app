// lib/models/task_model.dart
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskPriority { high, medium, low }
enum TaskType { task, agenda }

class TaskModel {
  final dynamic id; // dynamic because Odoo returns int, local mock returns String
  String name;
  String? description;
  DateTime deadline;
  bool isDone;
  TaskType type; // locally we can keep TaskType, defaulting to task
  String whatsappNumber;
  String email;
  bool remind1d; // Ingatkan H-1 Hari
  bool remind1h; // Ingatkan H-1 Jam
  bool isWaSent;
  String deviceId;
  DateTime createdAt;

  TaskPriority get priority {
    final now = DateTime.now();
    final difference = deadline.difference(now);
    if (difference.inHours <= 24) {
      return TaskPriority.high;
    } else if (difference.inHours <= 72) {
      return TaskPriority.medium;
    } else {
      return TaskPriority.low;
    }
  }

  // Backwards compatibility getters for existing widgets
  String get title => name;
  set title(String val) => name = val;
  String? get notes => description;
  set notes(String? val) => description = val;
  String? get time => DateFormat('HH:mm').format(deadline);
  bool get emailNotifEnabled => remind1d || remind1h;
  String? get emailAddress => email;
  bool get isEmailValid => email.contains('@');

  TaskModel({
    required this.id,
    required this.name,
    this.description,
    required this.deadline,
    TaskPriority? priority, // Kept for backward compatibility, ignored
    this.isDone = false,
    this.type = TaskType.task,
    this.whatsappNumber = '',
    this.email = '',
    this.remind1d = true, // Default to true
    this.remind1h = true, // Default to true
    this.isWaSent = false,
    this.deviceId = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Smart Priority Ranking score (lower = more urgent)
  double get priorityScore {
    final now = DateTime.now();
    final daysLeft = deadline.difference(now).inHours / 24.0;
    
    // Weight priority: high priority gets an urgency boost (subtracted score)
    double priorityWeight = 0.0;
    if (priority == TaskPriority.high) {
      priorityWeight = -2.0; // high priority is treated as 2 days closer
    } else if (priority == TaskPriority.low) {
      priorityWeight = 2.0;  // low priority is treated as 2 days further
    }

    return daysLeft + priorityWeight;
  }

  bool get isOverdue {
    return !isDone && DateTime.now().isAfter(deadline);
  }

  TaskModel copyWith({
    dynamic id,
    String? name,
    String? description,
    DateTime? deadline,
    TaskPriority? priority,
    bool? isDone,
    TaskType? type,
    String? whatsappNumber,
    String? email,
    bool? remind1d,
    bool? remind1h,
    bool? isWaSent,
    String? deviceId,
    DateTime? createdAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      isDone: isDone ?? this.isDone,
      type: type ?? this.type,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      email: email ?? this.email,
      remind1d: remind1d ?? this.remind1d,
      remind1h: remind1h ?? this.remind1h,
      isWaSent: isWaSent ?? this.isWaSent,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert TaskModel to local database JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'priority': priority.index,
      'isDone': isDone,
      'type': type.index,
      'whatsapp_number': whatsappNumber,
      'email': email,
      'remind_1d': remind1d,
      'remind_1h': remind1h,
      'is_wa_sent': isWaSent,
      'device_id': deviceId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create TaskModel from local database JSON
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'],
      name: json['name'] ?? json['title'] ?? '',
      description: json['description'] ?? json['notes'],
      deadline: DateTime.parse(json['deadline']),
      priority: TaskPriority.values[json['priority'] ?? 1],
      isDone: json['isDone'] ?? false,
      type: TaskType.values[json['type'] ?? 0],
      whatsappNumber: json['whatsapp_number'] ?? '',
      email: json['email'] ?? '',
      remind1d: json['remind_1d'] ?? false,
      remind1h: json['remind_1h'] ?? false,
      isWaSent: json['is_wa_sent'] ?? false,
      deviceId: json['device_id'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  /// Convert TaskModel to Odoo REST API compatible JSON payload
  Map<String, dynamic> toOdooJson() {
    String priorityStr = 'sedang';
    if (priority == TaskPriority.high) priorityStr = 'mendesak';
    if (priority == TaskPriority.low) priorityStr = 'santai';

    String stateStr = isDone ? 'selesai' : (isOverdue ? 'terlambat' : 'aktif');

    // Wajib menggunakan format ISO-8601 (YYYY-MM-DD HH:mm:ss) untuk Odoo
    String formattedDeadline = DateFormat('yyyy-MM-dd HH:mm:ss').format(deadline);

    return {
      'name': name,
      'description': description ?? '',
      'deadline': formattedDeadline,
      'priority': priorityStr,
      'state': stateStr,
      'device_id': deviceId,
      'whatsapp_number': whatsappNumber,
      'email': email,
      'is_wa_sent': isWaSent,
      'remind_1d': remind1d,
      'remind_1h': remind1h,
      'type': type.index,
    };
  }

  /// Create TaskModel from Odoo REST API JSON response
  factory TaskModel.fromOdooJson(Map<String, dynamic> json) {
    String priorityStr = json['priority'] ?? 'sedang';
    TaskPriority priorityVal = TaskPriority.medium;
    if (priorityStr == 'mendesak') priorityVal = TaskPriority.high;
    if (priorityStr == 'santai') priorityVal = TaskPriority.low;

    String stateStr = json['state'] ?? 'aktif';
    bool isDoneVal = (stateStr == 'selesai');

    // Robust parsing for Firestore Timestamp or String deadlines
    DateTime deadlineVal;
    final deadlineRaw = json['deadline'];
    if (deadlineRaw is Timestamp) {
      deadlineVal = deadlineRaw.toDate();
    } else if (deadlineRaw is String) {
      try {
        deadlineVal = DateTime.parse(deadlineRaw);
      } catch (_) {
        try {
          deadlineVal = DateFormat('yyyy-MM-dd HH:mm:ss').parse(deadlineRaw);
        } catch (_) {
          deadlineVal = DateTime.now();
        }
      }
    } else {
      deadlineVal = DateTime.now();
    }

    // Read task/agenda type from Firestore, default to TaskType.task (0)
    final typeIndex = json['type'] ?? 0;
    final typeVal = TaskType.values[typeIndex];

    return TaskModel(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      deadline: deadlineVal,
      priority: priorityVal,
      isDone: isDoneVal,
      type: typeVal,
      whatsappNumber: json['whatsapp_number'] ?? '',
      email: json['email'] ?? '',
      remind1d: json['remind_1d'] ?? false,
      remind1h: json['remind_1h'] ?? false,
      isWaSent: json['is_wa_sent'] ?? false,
      deviceId: json['device_id'] ?? '',
      createdAt: DateTime.now(), // not stored in Odoo schema
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory TaskModel.fromJsonString(String s) =>
      TaskModel.fromJson(jsonDecode(s));
}
