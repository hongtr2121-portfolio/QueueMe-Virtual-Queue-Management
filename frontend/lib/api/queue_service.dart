// api/queue_service.dart
// CHUẨN HÓA: Service xử lý queue, KHÔNG chứa QueueStatus để tránh trùng class.

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:queueapp/api/api_client.dart';
import 'package:queueapp/models/queue_entry.dart';
import 'package:queueapp/models/queue_status.dart';   // 👈 IMPORT MODEL CHUẨN

class QueueService {
  final Dio _dio = ApiClient.instance.dio;

  /// =====================
  ///  JOIN QUEUE
  /// =====================
  Future<QueueEntry> join({
    required int restaurantID,
    required int userID,
    required int queueTypeID,
    int partySize = 1,
    String? notes,
  }) async {
    try {
      final resp = await _dio.post(
        '/queue/join',
        data: {
          'restaurantID': restaurantID,
          'userID': userID,
          'queueTypeID': queueTypeID,
          'partySize': partySize,
          'notes': notes,
        },
      );

      return QueueEntry.fromJson(
        Map<String, dynamic>.from(resp.data as Map),
      );
    } on DioException catch (e) {
      debugPrint('joinQueue ERROR: ${e.response?.data}');
      rethrow;
    }
  }

  /// =====================
  ///  WEEKLY STATS (optional)
  /// =====================
  Future<List<int>> getWeeklyCounts(int restaurantID) async {
    try {
      final resp = await _dio.get(
        '/stats/weekly-queues',
        queryParameters: {'restaurantId': restaurantID},
      );

      final data = resp.data;
      if (data is List) {
        return data.map((e) => (e as num).toInt()).toList();
      }
    } catch (e) {
      debugPrint('getWeeklyCounts error: $e');
    }
    return List<int>.filled(7, 0);
  }

  /// =====================
  ///  CREATE BOOKING
  /// =====================
  Future<QueueEntry> createBooking({
    required int restaurantId,
    required int userId,
    required int queueTypeId,
    required DateTime scheduledTime,
    int partySize = 1,
    String? notes,
  }) async {
    final body = {
      'restaurantID': restaurantId,
      'userID': userId,
      'queueTypeID': queueTypeId,
      'partySize': partySize,
      'scheduledTime': scheduledTime.toIso8601String(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };

    final r = await _dio.post('/QueueEntries', data: body);
    return QueueEntry.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// =====================
  ///  UPDATE STATUS
  /// =====================
  Future<void> updateStatus(int queueEntryID, String status) async {
    await _dio.put(
      '/QueueEntries/$queueEntryID/status',
      data: {'status': status},
    );
  }

  /// =====================
  ///  DELETE ENTRY
  /// =====================
  Future<void> deleteEntry(int queueEntryID) async {
    await _dio.delete('/QueueEntries/$queueEntryID');
  }

  /// =====================
  ///  LIST QUEUE ENTRIES
  /// =====================
  Future<List<QueueEntry>> list({
    int? restaurantID,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    final r = await _dio.get(
      '/QueueEntries',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (restaurantID != null) 'restaurantId': restaurantID,
        if (status != null) 'status': status,
      },
    );

    return (r.data as List)
        .map((e) => QueueEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// =====================
  ///  CURRENT STATUS (REALTIME)
  /// =====================
  Future<QueueStatus> getCurrentStatus({
    required int restaurantID,
    required int userID,
  }) async {
    final r = await _dio.get(
      '/QueueEntries/current',
      queryParameters: {
        'restaurantId': restaurantID,
        'userId': userID,
      },
    );

    return QueueStatus.fromJson(
      Map<String, dynamic>.from(r.data as Map),
    );
  }

  /// =====================
  ///  ACTIVE TICKET
  /// =====================
  Future<QueueEntry?> getActiveTicket({
    required int userId,
    int? restaurantID,
  }) async {
    try {
      final resp = await _dio.get(
        '/QueueEntries/active',
        queryParameters: {
          'userId': userId,
          if (restaurantID != null) 'restaurantId': restaurantID,
        },
      );

      return QueueEntry.fromJson(
        Map<String, dynamic>.from(resp.data as Map),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// =====================
  ///  ADMIN — LIST QUEUE
  /// =====================
  Future<List<Map<String, dynamic>>> getAdminQueues({
    required int restaurantId,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    final resp = await _dio.get(
      '/QueueEntries',
      queryParameters: {
        'restaurantId': restaurantId,
        'page': page,
        'pageSize': pageSize,
        if (status != null) 'status': status,
      },
    );

    return (resp.data as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// =====================
  ///  ADMIN — UPDATE STATUS
  /// =====================
  Future<void> updateQueueStatus({
    required int queueEntryId,
    required String status,
  }) async {
    await updateStatus(queueEntryId, status);
  }

  /// =====================
  ///  CANCEL TICKET (USER LEAVE QUEUE)
  ///  Backend only accepts: Waiting, Called, InService, Completed, Canceled, NoShow
  /// =====================
  Future<void> cancelTicket({
    required int queueEntryID,
  }) async {
    await updateStatus(queueEntryID, "Canceled"); // ✅ đúng theo backend
  }

  Future<void> finishMeal({required int queueEntryID}) async {
    await updateStatus(queueEntryID, "Completed");
  }

}
