// lib/api/nominatim_service.dart
// =====================================
// Service gọi Nominatim (OpenStreetMap)
// - searchNearby: tìm địa điểm quanh 1 tâm (lat, lon)
// - reverseGeocode: từ toạ độ -> địa chỉ
// =====================================

import 'package:dio/dio.dart';

class NominatimService {
  // Dùng Dio riêng, baseUrl = Nominatim
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://nominatim.openstreetmap.org',
      headers: {
        // Nominatim yêu cầu User-Agent / email lịch sự
        'User-Agent': 'QueueApp/1.0 (hongtran210505@gmail.com)',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Tìm địa điểm quanh 1 tâm (lat, lon) trong 1 bounding box nhỏ
  ///
  /// [lat], [lon] : tâm bản đồ
  /// [keyword]    : từ khoá (vd: "restaurant", "cafe", "pharmacy"...)
  /// [boxDelta]   : độ rộng box (độ), 0.02 ~ 2km tuỳ vĩ độ
  /// [limit]      : số lượng kết quả tối đa
  ///
  /// Trả về: List<Map<String, dynamic>> (mỗi phần tử là 1 kết quả JSON)
  Future<List<Map<String, dynamic>>> searchNearby({
    required double lat,
    required double lon,
    String keyword = 'restaurant',
    double boxDelta = 0.02,
    int limit = 30,
  }) async {
    // Tính bounding box quanh tâm
    final left   = lon - boxDelta;
    final right  = lon + boxDelta;
    final top    = lat + boxDelta;
    final bottom = lat - boxDelta;

    final resp = await _dio.get(
      '/search',
      queryParameters: {
        'format': 'json',
        'q': keyword,
        'limit': limit,
        'viewbox': '$left,$top,$right,$bottom',
        'bounded': 1, // chỉ lấy trong box
      },
    );

    // Nominatim trả về List<dynamic>
    final data = resp.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    // Nếu không phải list thì trả list rỗng
    return <Map<String, dynamic>>[];
  }

  /// Reverse geocode:
  /// - Cho lat, lon -> trả về 1 object JSON có display_name, address...
  /// - Nếu lỗi hoặc không đúng format thì trả null
  Future<Map<String, dynamic>?> reverseGeocode(double lat, double lon) async {
    final resp = await _dio.get(
      '/reverse',
      queryParameters: {
        'format': 'json',
        'lat': lat,
        'lon': lon,
      },
    );

    final data = resp.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    return null;
  }
  Future<String?> _getDistrictFromLatLng(double lat, double lon) async {
    try {
      final res = await reverseGeocode(lat, lon);

      if (res == null) return null;

      final address = res['address'];
      if (address == null) return null;

      // Lấy theo thứ tự ưu tiên
      // (ở VN thường nằm trong 'suburb', 'city_district', 'district')
      final district = address['city_district'] ??
          address['district'] ??
          address['suburb'];

      final city = address['city'] ?? address['town'] ?? address['state'];

      if (district != null && city != null) {
        return '$district, $city';
      }
      return res['display_name']; // fallback
    } catch (_) {
      return null;
    }
  }
  /// Forward geocode:
  /// - Cho address string -> trả về lat/lon + display_name (nếu tìm thấy)
  /// - Nếu không tìm thấy -> trả null
  Future<Map<String, dynamic>?> geocodeAddress(String address) async {
    final q = address.trim();
    if (q.isEmpty) return null;

    final resp = await _dio.get(
      '/search',
      queryParameters: {
        'format': 'json',
        'q': q,
        'limit': 1,
        'addressdetails': 1,
      },
    );

    final data = resp.data;
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return null;
  }
}
