// api/notification_service.dart
import 'package:dio/dio.dart';
import 'package:queueapp/api/api_client.dart';
import 'package:queueapp/models/notification.dart';

class NotificationService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<AppNotification>> forUser(int userId) async {
    try {
      final r = await _dio.get('/Notifications/user/$userId');

      // Backend trả về list json
      final data = r.data;
      if (data is List) {
        return data.map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))).toList();
      }
      return [];
    } on DioException catch (e) {
      // Backend trả 404 nghĩa là danh sách rỗng -> Return mảng rỗng, KHÔNG throw lỗi ra UI
      if (e.response?.statusCode == 404) {
        return [];
      }
      // Các lỗi khác (500, mất mạng) thì throw để UI hiện nút "Thử lại"
      rethrow;
    }
  }

  Future<void> markAsRead(int notificationId) async {
    // Tận dụng API update status để đánh dấu đã đọc (isSent = true)
    try {
      await _dio.put(
        '/Notifications/$notificationId/status',
        data: {'isSent': true},
      );
    } catch (_) {
      // Lỗi đánh dấu không quan trọng, có thể bỏ qua silent
    }
  }
}