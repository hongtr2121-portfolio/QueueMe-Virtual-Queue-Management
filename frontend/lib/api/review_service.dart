import 'package:dio/dio.dart';
import 'package:queueapp/api/api_client.dart';

class ReviewService {
  final Dio _dio = ApiClient.instance.dio;

  Future<void> createReview({
    required int restaurantId,
    required int userId,
    required int rating, // 1..5
    String? comment,
  }) async {
    try {
      await _dio.post(
        '/RestaurantReviews',
        data: {
          'restaurantId': restaurantId,
          'userId': userId,
          'rating': rating,
          'comment': comment,
        },
      );
    } on DioException catch (e) {
      // show message từ backend nếu có
      final msg = e.response?.data is Map
          ? (e.response?.data['message']?.toString() ?? e.message)
          : e.message;
      throw Exception(msg ?? 'Gửi đánh giá thất bại');
    }
  }

  Future<bool> hasReviewed({
    required int restaurantId,
    required int userId,
  }) async {
    try {
      final res = await _dio.get(
        '/RestaurantReviews/exists',
        queryParameters: {'restaurantId': restaurantId, 'userId': userId},
      );
      return res.data == true;
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message']?.toString() ?? e.message)
          : e.message;
      throw Exception(msg ?? 'Không kiểm tra được trạng thái đánh giá');
    }
  }
}
