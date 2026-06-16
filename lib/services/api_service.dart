// lib/services/api_service.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';

class AppGlobals {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
}

class ApiService {
  // Keeping this for temporary backward compatibility
  static String? customOdooUrl;

  /// Show red error SnackBar if connection fails
  static void _showConnectionError(Object? error) {
    String message = 'Koneksi ke peladen gagal';
    if (error != null) {
      final errStr = error.toString();
      if (errStr.contains('core/not-initialized') || errStr.contains('initialization')) {
        message += ' (Firebase belum dikonfigurasi)';
      } else if (errStr.contains('permission-denied')) {
        message += ' (Akses ditolak di Firestore)';
      } else if (errStr.contains('network-request-failed') || errStr.contains('SocketException')) {
        message += ' (Periksa koneksi internet Anda)';
      } else {
        final details = errStr.length > 50 ? '${errStr.substring(0, 47)}...' : errStr;
        message += ' ($details)';
      }
    }

    AppGlobals.scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    AppGlobals.scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// GET /tasks (filtered by deviceId)
  static Future<List<TaskModel>> fetchTasks({String? deviceId, String? state, DateTime? date}) async {
    try {
      Query query = FirebaseFirestore.instance.collection('tasks');
      if (deviceId != null && deviceId.isNotEmpty) {
        query = query.where('device_id', isEqualTo: deviceId);
      }

      final snapshot = await query.get();
      final List<TaskModel> list = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Map Firestore document ID
        final task = TaskModel.fromOdooJson(data);
        
        // Client-side date and state filters for exact matching if required
        if (state != null && data['state'] != state) continue;
        if (date != null) {
          final d = task.deadline;
          if (d.year != date.year || d.month != date.month || d.day != date.day) {
            continue;
          }
        }
        list.add(task);
      }
      return list;
    } catch (e) {
      debugPrint('Error fetchTasks: $e');
      _showConnectionError(e);
      throw Exception('Koneksi ke peladen gagal');
    }
  }

  /// POST /task/create (save to Firestore)
  static Future<TaskModel?> createTask(TaskModel task) async {
    try {
      final docRef = await FirebaseFirestore.instance
          .collection('tasks')
          .add(task.toOdooJson());
      return task.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('Error createTask: $e');
      _showConnectionError(e);
      throw Exception('Koneksi ke peladen gagal');
    }
  }

  /// GET /stats (calculated dynamically from Firestore based on deviceId)
  static Future<Map<String, dynamic>?> fetchStats({String? deviceId}) async {
    try {
      Query query = FirebaseFirestore.instance.collection('tasks');
      if (deviceId != null && deviceId.isNotEmpty) {
        query = query.where('device_id', isEqualTo: deviceId);
      }

      final snapshot = await query.get();
      int total = 0;
      int selesai = 0;
      int terlambat = 0;
      int mendesak = 0;
      int sedang = 0;
      int santai = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final state = data['state'] ?? 'aktif';
        final priority = data['priority'] ?? 'sedang';

        total++;
        if (state == 'selesai') {
          selesai++;
        } else {
          // Check if it is overdue
          final deadlineStr = data['deadline'];
          if (deadlineStr != null) {
            try {
              DateTime deadlineVal;
              try {
                deadlineVal = DateTime.parse(deadlineStr);
              } catch (_) {
                deadlineVal = DateFormat('yyyy-MM-dd HH:mm:ss').parse(deadlineStr);
              }
              if (DateTime.now().isAfter(deadlineVal)) {
                terlambat++;
              }
            } catch (_) {}
          }
        }

        if (state != 'selesai') {
          if (priority == 'mendesak') {
            mendesak++;
          } else if (priority == 'sedang') {
            sedang++;
          } else if (priority == 'santai') {
            santai++;
          }
        }
      }

      return {
        'total_tugas': total,
        'total_selesai': selesai,
        'total_terlambat': terlambat,
        'priority_distribution': {
          'mendesak': mendesak,
          'sedang': sedang,
          'santai': santai,
        }
      };
    } catch (e) {
      debugPrint('Error fetchStats: $e');
      _showConnectionError(e);
      return null;
    }
  }

  /// POST /task/update/<id>
  static Future<bool> updateTaskState(dynamic id, String state) async {
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(id.toString())
          .update({'state': state});
      return true;
    } catch (e) {
      debugPrint('Error updateTaskState: $e');
      return false;
    }
  }

  /// DELETE /task/delete/<id>
  static Future<bool> deleteTask(dynamic id) async {
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(id.toString())
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error deleteTask: $e');
      return false;
    }
  }
}
