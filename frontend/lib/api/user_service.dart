import 'package:dio/dio.dart';
import 'package:queueapp/api/api_client.dart';
import 'package:queueapp/models/user.dart';

class UserService {
  final Dio _dio = ApiClient.instance.dio;

  /// GET: api/Users/{id}
  Future<User?> getById(int id) async {
    try {
      final r = await _dio.get('/Users/$id');

      if (r.data == null) return null;

      return User.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // Nếu là lỗi 404 → trả null (user không tồn tại)
      if (e.response?.statusCode == 404) return null;

      rethrow; // các lỗi khác ném ngược ra
    }
  }
}
