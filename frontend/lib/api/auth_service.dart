import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

class AuthService {
  final _api = ApiClient.instance;
  final _storage = const FlutterSecureStorage();

  // ---- hàm decode JWT dùng chung ----
  Map<String, dynamic> _decodeJwt(String tkn) {
    final parts = tkn.split('.');
    if (parts.length != 3) throw Exception('JWT không hợp lệ.');
    final payload =
    utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    return json.decode(payload) as Map<String, dynamic>;
  }

  // =====================================================
  //                      LOGIN
  // =====================================================
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await _api.dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      print('🔐 LOGIN status = ${res.statusCode}');
      print('🔐 LOGIN body   = ${res.data}');

      if (res.data is! Map) {
        throw Exception('Phản hồi đăng nhập không phải JSON object.');
      }
      final data = Map<String, dynamic>.from(res.data as Map);

      final token = data['token']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('Server không trả token.');
      }

      // ====== USER ID / TYPE ======
      final userId   = (data['userID'] ?? data['userId'] ?? '').toString();
      final userType = data['userType']?.toString() ?? 'Customer';

      // ====== ĐỌC displayName CŨ (NẾU CÓ) ======
      final oldDisplayName = await _storage.read(key: 'displayName');

      // ====== ƯU TIÊN: firstName + lastName từ body (nếu backend có trả) ======
      String displayName = '';

      String? firstNameBody = data['firstName']?.toString().trim();
      String? lastNameBody  = data['lastName']?.toString().trim();

      if ((firstNameBody != null && firstNameBody.isNotEmpty) ||
          (lastNameBody != null && lastNameBody.isNotEmpty)) {
        displayName = '${firstNameBody ?? ''} ${lastNameBody ?? ''}'.trim();
      }

      // ====== Nếu body không có tên -> thử JWT ======
      if (displayName.isEmpty) {
        try {
          final claims = _decodeJwt(token);

          final rawName = (claims['given_name'] ??   // first name
              claims['name'] ??                  // full name
              claims['unique_name'] ??           // username
              '')
              .toString()
              .trim();

          if (rawName.isNotEmpty) {
            displayName = rawName;
          }
        } catch (e) {
          print('⚠️ LOGIN decode JWT name error: $e');
        }
      }

      // ====== Nếu vẫn chưa có tên:
      //  - Nếu đã có displayName cũ (không rỗng) -> GIỮ NGUYÊN
      //  - Nếu chưa có gì -> mới dùng email làm fallback
      if (displayName.isEmpty) {
        if (oldDisplayName != null && oldDisplayName.trim().isNotEmpty) {
          displayName = oldDisplayName.trim();
        } else {
          displayName = email; // lần đầu login mà chưa có tên -> tạm dùng email
        }
      }

      // ===== LƯU STORAGE =====
      await _storage.write(key: 'jwt',         value: token);
      await _storage.write(key: 'userId',      value: userId);
      await _storage.write(key: 'userType',    value: userType);
      await _storage.write(key: 'displayName', value: displayName);
      await _storage.write(key: 'email',       value: email);

      // cho interceptor dùng
      await _api.saveToken(token);

      return data;
    } on DioException catch (e) {
      print('❌ LOGIN DioException type  = ${e.type}');
      print('❌ LOGIN DioException code  = ${e.response?.statusCode}');
      print('❌ LOGIN DioException body  = ${e.response?.data}');

      final status = e.response?.statusCode;
      final body   = e.response?.data;

      String? serverMsg;
      if (body is Map && body['message'] != null) {
        serverMsg = body['message'].toString();
      } else if (body != null) {
        serverMsg = body.toString();
      }

      if (status == null) {
        throw Exception(
          'Không kết nối được tới server. Kiểm tra lại Wi-Fi, IP, port hoặc backend.',
        );
      }
      if (status == 401) {
        throw Exception(serverMsg ?? 'Sai email hoặc mật khẩu.');
      }
      if (status == 403) {
        throw Exception(
          serverMsg ?? 'Tài khoản chưa được xác minh hoặc không có quyền.',
        );
      }

      throw Exception(
        'Đăng nhập lỗi (HTTP $status): ${serverMsg ?? 'Lỗi không rõ.'}',
      );
    } catch (e) {
      print('❌ LOGIN other error: $e');
      throw Exception('Đăng nhập thất bại: $e');
    }
  }


  // =====================================================
  //                     REGISTER
  // =====================================================
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    String userType = 'Customer',
  }) async {
    try {
      final res = await _api.dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'phoneNumber': phoneNumber,
          'firstName': firstName,
          'lastName': lastName,
          'userType': userType,
        },
      );

      print('📝 REGISTER status = ${res.statusCode}');
      print('📝 REGISTER body   = ${res.data}');

      final data = Map<String, dynamic>.from(res.data);
      final token = data['token']?.toString();

      // Dù backend có trả token hay không, ta cũng cố gắng lưu thông tin cơ bản
      final userId = (data['userID'] ?? data['userId'] ?? '').toString();
      final uType  = data['userType']?.toString() ?? userType;

      // ====== ƯU TIÊN: firstName + lastName TỪ THAM SỐ (UI gửi lên) ======
      String displayName = '';
      if ((firstName != null && firstName.trim().isNotEmpty) ||
          (lastName != null && lastName.trim().isNotEmpty)) {
        displayName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
      }

      // ====== Nếu người dùng không nhập tên -> thử đọc từ body ======
      if (displayName.isEmpty) {
        String? fBody = data['firstName']?.toString().trim();
        String? lBody = data['lastName']?.toString().trim();
        if ((fBody != null && fBody.isNotEmpty) ||
            (lBody != null && lBody.isNotEmpty)) {
          displayName = '${fBody ?? ''} ${lBody ?? ''}'.trim();
        }
      }

      // ====== Nếu vẫn trống -> fallback dùng email ======
      if (displayName.isEmpty) {
        displayName = email;
      }

      // ====== LƯU TOKEN (NẾU CÓ) ======
      if (token != null && token.isNotEmpty) {
        await _storage.write(key: 'jwt', value: token);
        await _api.saveToken(token);
      }

      // ====== LƯU THÔNG TIN USER ======
      await _storage.write(key: 'userId',      value: userId);
      await _storage.write(key: 'userType',    value: uType);
      await _storage.write(key: 'displayName', value: displayName);
      await _storage.write(key: 'email',       value: email);

      return data;
    } on DioException catch (e) {
      print(
          '❌ REGISTER DioException: ${e.response?.statusCode} - ${e.response?.data}');
      throw Exception(
        'Đăng ký thất bại: ${e.response?.data ?? e.message ?? 'Lỗi không xác định.'}',
      );
    } catch (e) {
      print('❌ REGISTER other error: $e');
      throw Exception('Đăng ký thất bại: $e');
    }
  }

  // =====================================================
  //                     LOGOUT
  // =====================================================
  Future<void> logout() async {
    await _api.clearToken();
    await _storage.deleteAll();
  }
}
