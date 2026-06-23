import 'package:dio/dio.dart';

class OsmPlace {
  final String name;
  final double lat;
  final double lon;
  final String displayName;

  OsmPlace({
    required this.name,
    required this.lat,
    required this.lon,
    required this.displayName,
  });

  factory OsmPlace.fromJson(Map<String, dynamic> j) {
    return OsmPlace(
      name: (j['name'] ?? j['display_name'] ?? 'Unknown').toString(),
      lat: double.tryParse(j['lat']?.toString() ?? '0') ?? 0,
      lon: double.tryParse(j['lon']?.toString() ?? '0') ?? 0,
      displayName: (j['display_name'] ?? '').toString(),
    );
  }
}

class OsmPlacesService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://nominatim.openstreetmap.org',
      // Nominatim yêu cầu User-Agent / email lịch sự
      headers: {
        'User-Agent': 'QueueApp/1.0 (your_email@example.com)',
      },
    ),
  );

  /// Tìm nhà hàng quanh vị trí (lat, lon) trong 1 bounding box nhỏ.
  Future<List<OsmPlace>> searchNearbyRestaurants({
    required double lat,
    required double lon,
    int limit = 10,
  }) async {
    // Tạo bounding box quanh vị trí hiện tại
    const delta = 0.01; // ~1km tuỳ vĩ độ
    final left   = lon - delta;
    final right  = lon + delta;
    final top    = lat + delta;
    final bottom = lat - delta;

    final resp = await _dio.get(
      '/search',
      queryParameters: {
        'format': 'json',
        'limit': limit,
        'q': 'restaurant',
        'viewbox': '$left,$top,$right,$bottom',
        'bounded': 1,
      },
    );

    final data = resp.data as List;
    return data.map((e) => OsmPlace.fromJson(e as Map<String, dynamic>)).toList();
  }
}
