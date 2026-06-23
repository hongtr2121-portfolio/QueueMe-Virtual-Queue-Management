import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  // ====== 1️⃣ Singleton Pattern ======
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  // ⚠️ Base URL - bạn có thể đổi khi deploy
  // Dùng 10.0.2.2 cho emulator Android, hoặc IP LAN nếu chạy thật
  static const String _baseUrl = 'http://192.168.1.15:5266/api';

  // ====== 2️⃣ Secure Storage ======
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ====== 3️⃣ DIO Configuration ======
  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  )
  // interceptor 1: tự động thêm Authorization header nếu có token
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    )
  // interceptor 2: retry nhẹ nếu lỗi mạng (502,503,504)
    ..interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) async {
          final retryable = e.type == DioExceptionType.connectionError ||
              e.response?.statusCode == 502 ||
              e.response?.statusCode == 503 ||
              e.response?.statusCode == 504;
          if (!retryable) return handler.next(e);

          const maxRetry = 2;
          final attempt = (e.requestOptions.extra['retry_attempt'] as int?) ?? 0;
          if (attempt >= maxRetry) return handler.next(e);

          await Future.delayed(Duration(milliseconds: 400 * (1 << attempt)));
          final newReq = e.requestOptions.copyWith(
            extra: {...e.requestOptions.extra, 'retry_attempt': attempt + 1},
          );
          try {
            final res = await dio.request<Object?>(
              newReq.path,
              data: newReq.data,
              queryParameters: newReq.queryParameters,
              options: Options(method: newReq.method, headers: newReq.headers),
            );
            return handler.resolve(res);
          } catch (_) {
            return handler.next(e);
          }
        },
      ),
    );

  // ====== 4️⃣ Token helpers ======
  Future<void> saveToken(String token) async =>
      _storage.write(key: 'jwt', value: token);

  Future<String?> readToken() async => _storage.read(key: 'jwt');

  Future<void> clearToken() async => _storage.delete(key: 'jwt');

  // ====== 5️⃣ Hàm tiện ích gọi API nhanh ======
  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? query}) async {
    return dio.get(path, queryParameters: query);
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) async {
    return dio.post(path, data: data);
  }

  Future<Response<T>> put<T>(String path, {dynamic data}) async {
    return dio.put(path, data: data);
  }

  Future<Response<T>> delete<T>(String path) async {
    return dio.delete(path);
  }
}
