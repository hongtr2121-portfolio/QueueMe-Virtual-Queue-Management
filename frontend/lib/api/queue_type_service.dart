// api/queue_type_service.dart
import 'package:dio/dio.dart';
import 'package:queueapp/api/api_client.dart';
import 'package:queueapp/models/queue_type.dart';

class QueueTypeService {
  final Dio _dio = ApiClient.instance.dio;

  // ---------------------------------------------------------------------------
  // 1) Lấy danh sách QueueType theo Restaurant
  // ---------------------------------------------------------------------------
  Future<List<QueueType>> getByRestaurant(int restaurantID) async {
    try {
      final res = await _dio.get('/QueueTypes/by-restaurant/$restaurantID');

      final raw = res.data;
      if (raw is List) {
        return raw
            .map((e) => QueueType.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      return [];
    } catch (e) {
      print("QueueTypeService.getByRestaurant ERROR: $e");
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 2) Tạo QueueType mới
  // ---------------------------------------------------------------------------
  Future<QueueType?> createQueueType({
    required int restaurantID,
    required String name,
    required int maxPartySize,
    required int durationMinutes,
    bool isActive = true,
  }) async {
    try {
      final res = await _dio.post(
        '/QueueTypes',
        data: {
          'restaurantID': restaurantID,
          'name': name,
          'maxPartySize': maxPartySize,
          'standardServiceDuration': durationMinutes,
          'isActive': isActive,
        },
      );

      return QueueType.fromJson(
        Map<String, dynamic>.from(res.data),
      );
    } catch (e) {
      print("QueueTypeService.createQueueType ERROR: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 3) Cập nhật QueueType
  // ---------------------------------------------------------------------------
  Future<QueueType?> updateQueueType({
    required int queueTypeID,
    required String name,
    required int maxPartySize,
    required int durationMinutes,
    required bool isActive,
  }) async {
    try {
      final res = await _dio.put(
        '/QueueTypes/$queueTypeID',
        data: {
          'name': name,
          'maxPartySize': maxPartySize,
          'standardServiceDuration': durationMinutes,
          'isActive': isActive,
        },
      );

      return QueueType.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      print("QueueTypeService.updateQueueType ERROR: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 4) Xoá QueueType
  // ---------------------------------------------------------------------------
  Future<bool> deleteQueueType(int queueTypeID) async {
    try {
      await _dio.delete('/QueueTypes/$queueTypeID');
      return true;
    } catch (e) {
      print("QueueTypeService.deleteQueueType ERROR: $e");
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 5) Toggle Active / Inactive
  // ---------------------------------------------------------------------------
  Future<QueueType?> toggleStatus(int queueTypeID) async {
    try {
      final res = await _dio.patch('/QueueTypes/$queueTypeID/toggle');
      return QueueType.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      print("QueueTypeService.toggleStatus ERROR: $e");
      return null;
    }
  }
}
