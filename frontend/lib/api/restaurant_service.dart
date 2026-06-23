// api/restaurant_service.dart
// MỤC ĐÍCH: Gói các API Restaurants để UI gọi ngắn gọn – sạch sẽ.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:queueapp/api/api_client.dart';
import 'package:queueapp/models/restaurant.dart';

class RestaurantService {
  final Dio _dio = ApiClient.instance.dio;

  // ================== GET LIST ==================
  Future<List<Restaurant>> getRestaurants({
    int page = 1,
    int pageSize = 50,
    String? search,
  }) async {
    try {
      final res = await _dio.get(
        '/Restaurants',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );

      // Đảm bảo đúng kiểu List
      if (res.data is! List) {
        debugPrint('getRestaurants: data không phải List: ${res.data}');
        return [];
      }

      final list = (res.data as List)
          .map((e) => Restaurant.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      return list;
    } on DioException catch (e) {
      debugPrint('getRestaurants ERROR: ${e.response?.statusCode} ${e.message}');
      debugPrint('BODY: ${e.response?.data}');
      rethrow; // để UI tự quyết định show error hay retry
    } catch (e, s) {
      debugPrint('getRestaurants UNKNOWN ERROR: $e');
      debugPrint('$s');
      rethrow;
    }
  }

  // ================== GET BY ID ==================
  Future<Restaurant> getById(int id) async {
    try {
      final res = await _dio.get('/Restaurants/$id');

      if (res.data is! Map) {
        debugPrint('getById: data không phải Map: ${res.data}');
        throw Exception('Dữ liệu không hợp lệ');
      }

      return Restaurant.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    } on DioException catch (e) {
      debugPrint('getById ERROR: ${e.response?.statusCode} ${e.message}');
      debugPrint('BODY: ${e.response?.data}');
      rethrow;
    } catch (e, s) {
      debugPrint('getById UNKNOWN ERROR: $e');
      debugPrint('$s');
      rethrow;
    }
  }

  // ================== QUEUE STATS ==================
  Future<Map<String, int>> getQueueStats(int restaurantId) async {
    try {
      final res = await _dio.get('/Restaurants/$restaurantId/queue-stats');

      if (res.data is! Map) {
        debugPrint('getQueueStats: data không phải Map: ${res.data}');
        return {
          'waiting': 0,
          'called': 0,
          'completed': 0,
        };
      }

      final j = res.data as Map<String, dynamic>;
      return {
        'waiting': (j['waiting'] as num?)?.toInt() ?? 0,
        'called': (j['called'] as num?)?.toInt() ?? 0,
        'completed': (j['completed'] as num?)?.toInt() ?? 0,
      };
    } on DioException catch (e) {
      debugPrint('getQueueStats ERROR: ${e.response?.statusCode} ${e.message}');
      debugPrint('BODY: ${e.response?.data}');
      // nếu lỗi thì trả 0 để UI không bị crash
      return {
        'waiting': 0,
        'called': 0,
        'completed': 0,
      };
    } catch (e, s) {
      debugPrint('getQueueStats UNKNOWN ERROR: $e');
      debugPrint('$s');
      return {
        'waiting': 0,
        'called': 0,
        'completed': 0,
      };
    }
  }

  // ================== CREATE ==================
  /// Gửi đúng structure backend yêu cầu.
  Future<Restaurant> create({
    required String name,
    String? address,
    String? operatingHours,
    double? overallRating,
    int? adminUserId,
    double? latitude,
    double? longitude,
  }) async {
    final body = <String, dynamic>{
      "name": name,
      "address": address,
      "operatingHours": operatingHours,
      "overallRating": overallRating,
      "adminUserID": adminUserId,
      "latitude": latitude,
      "longitude": longitude,
    }..removeWhere((key, value) => value == null);

    try {
      final res = await _dio.post('/Restaurants', data: body);

      if (res.data is! Map) {
        debugPrint('create: data không phải Map: ${res.data}');
        throw Exception('Dữ liệu không hợp lệ');
      }

      return Restaurant.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    } on DioException catch (e) {
      debugPrint('createRestaurant ERROR: ${e.response?.statusCode} ${e.message}');
      debugPrint('BODY: ${e.response?.data}');
      rethrow;
    } catch (e, s) {
      debugPrint('createRestaurant UNKNOWN ERROR: $e');
      debugPrint('$s');
      rethrow;
    }
  }

  // ================== UPDATE ==================
  Future<void> updateRestaurant(int id, Restaurant r) async {
    final data = {
      "name": r.name,
      "address": r.address,
      "operatingHours": r.operatingHours,
      "overallRating": r.overallRating,
      "adminUserID": r.adminUserID,
      "latitude": r.latitude,
      "longitude": r.longitude,
      "googlePlaceID": r.googlePlaceID,
    }..removeWhere((k, v) => v == null);

    try {
      // Backend thường trả 204 NoContent hoặc 200 không body
      await _dio.put('/Restaurants/$id', data: data);
      // Không cố parse res.data nữa
    } on DioException catch (e) {
      debugPrint(
          'updateRestaurant ERROR: ${e.response?.statusCode} ${e.message}');
      debugPrint('BODY: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('updateRestaurant UNKNOWN ERROR: $e');
      rethrow;
    }
  }

  // ================== DELETE ==================
  Future<void> deleteRestaurant(int id) async {
    try {
      await _dio.delete('/Restaurants/$id');
    } on DioException catch (e) {
      debugPrint('deleteRestaurant ERROR: ${e.response?.statusCode} ${e.message}');
      debugPrint('BODY: ${e.response?.data}');
      rethrow;
    } catch (e, s) {
      debugPrint('deleteRestaurant UNKNOWN ERROR: $e');
      debugPrint('$s');
      rethrow;
    }
  }

  // ================== ENSURE FROM OSM ==================
  Future<int?> ensureFromOsm({
    required String name,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final url = '/Restaurants/ensure-from-osm';

    try {
      final res = await _dio.post(
        url,
        data: {
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        }..removeWhere((k, v) => v == null),
      );

      if (res.data is! Map) {
        debugPrint('ensureFromOsm: data không phải Map: ${res.data}');
        return null;
      }

      final data = res.data as Map<String, dynamic>;
      final raw = data['restaurantID'] ?? data['RestaurantID'];
      return raw == null ? null : (raw as num).toInt();
    } on DioException catch (e) {
      debugPrint('ensureFromOsm ERROR: ${e.response?.statusCode} ${e.message}');
      debugPrint('BODY: ${e.response?.data}');
      return null;
    } catch (e, s) {
      debugPrint('ensureFromOsm UNKNOWN ERROR: $e');
      debugPrint('$s');
      return null;
    }
  }
}
