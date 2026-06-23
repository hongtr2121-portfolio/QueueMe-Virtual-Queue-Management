// MỤC ĐÍCH: Đưa ra thông điệp tiếng Việt rõ ràng cho người dùng.
import 'package:dio/dio.dart';

String mapError(Object e) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    final msg = e.response?.data is Map<String, dynamic>
        ? (e.response?.data['message']?.toString())
        : null;

    if (code == 400) return msg ?? 'Dữ liệu gửi lên không hợp lệ.';
    if (code == 401) return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    if (code == 403) return 'Bạn không có quyền thực hiện thao tác này.';
    if (code == 404) return 'Không tìm thấy dữ liệu.';
    if (code == 409) return msg ?? 'Dữ liệu xung đột. Vui lòng thử lại.';
    if (code == 500) return 'Hệ thống đang gặp sự cố. Vui lòng thử lại sau.';

    // Mất mạng / timeout / server unreachable
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Không thể kết nối máy chủ. Kiểm tra mạng và thử lại.';
    }
    return 'Lỗi mạng không xác định.';
  }
  return e.toString();
}
