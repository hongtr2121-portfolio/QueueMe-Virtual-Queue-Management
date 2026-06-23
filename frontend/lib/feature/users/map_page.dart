import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:queueapp/api/nominatim_service.dart';
import 'package:queueapp/api/restaurant_service.dart';
import 'package:queueapp/models/restaurant.dart';

/// ===============================================================
/// MapPage
/// - Hiển thị bản đồ (flutter_map + OSM tiles)
/// - Gọi Nominatim searchNearby để lấy "nhà hàng gần bạn" → vẽ markers
/// - Không xin quyền vị trí: dùng tâm mặc định (TP.HCM) hoặc user tự gõ tìm kiếm
/// - onTap vào map: lụm toạ độ, reverse geocode để hiện địa chỉ
/// - Nhấn marker → mở bottom sheet → có nút "Lưu & Xếp hàng"
///   + Gọi API tạo Restaurant trong DB (AdminUserID = null / 0 tuỳ backend)
/// ===============================================================
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _nominatim = NominatimService();
  final _mapCtrl = MapController();

  // Service backend để tạo Restaurant
  final _restaurantSvc = RestaurantService();

  // Tâm bản đồ mặc định: TP.HCM
  final LatLng _defaultCenter = const LatLng(10.776889, 106.700806);

  // State hiển thị
  bool _loading = false;
  List<_Place> _places = [];     // danh sách điểm (kết quả từ Nominatim)
  LatLng? _picked;               // toạ độ user vừa tap vào map
  String? _pickedAddress;        // địa chỉ reverse geocode tại điểm tap

  // Thanh search
  final TextEditingController _searchCtrl =
  TextEditingController(text: 'restaurant');

  @override
  void initState() {
    super.initState();
    // Tải mặc định: "restaurant" quanh TP.HCM
    _searchNearby(center: _defaultCenter, keyword: _searchCtrl.text.trim());
  }

  /// Gọi Nominatim để tìm địa điểm quanh tâm `center`
  Future<void> _searchNearby({
    required LatLng center,
    required String keyword,
  }) async {
    setState(() => _loading = true);
    try {
      final data = await _nominatim.searchNearby(
        lat: center.latitude,
        lon: center.longitude,
        keyword: (keyword.isEmpty ? 'restaurant' : keyword),
        boxDelta: 0.02,
        limit: 30,
      );

      // Map JSON -> model _Place
      final mapped = data
          .map((e) {
        final lat = double.tryParse(e['lat']?.toString() ?? '');
        final lon = double.tryParse(e['lon']?.toString() ?? '');
        return _Place(
          name: (e['display_name'] ?? 'Unknown').toString(),
          lat: lat,
          lon: lon,
          category: (e['class'] ?? '').toString(),
          type: (e['type'] ?? '').toString(),
        );
      })
          .where((p) => p.lat != null && p.lon != null)
          .toList();

      if (!mounted) return;
      setState(() => _places = mapped);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được dữ liệu: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Reverse geocode khi user tap vào map
  Future<void> _reverseAt(LatLng point) async {
    setState(() {
      _picked = point;
      _pickedAddress = null;
    });
    try {
      final res =
      await _nominatim.reverseGeocode(point.latitude, point.longitude);
      if (!mounted) return;
      setState(() {
        _pickedAddress = res?['display_name']?.toString();
      });
    } catch (_) {
      // Không cần báo lỗi to, giữ UI gọn
    }
  }

  /// Lưu địa điểm từ Nominatim vào database như 1 Restaurant
  ///
  /// Dùng RestaurantService.create(...) (API mới) → trả về Restaurant có ID.
  Future<Restaurant?> _savePlaceToRestaurant(_Place p) async {
    try {
      final created = await _restaurantSvc.create(
        name: p.primaryName,        // tên ngắn
        address: p.name,            // display_name đầy đủ
        overallRating: null,
        adminUserId: null,          // quán cào từ map, chưa gán admin
        // 2 dòng dưới chỉ dùng nếu RestaurantService.create có khai báo:
        latitude: p.lat,
        longitude: p.lon,
      );

      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu nhà hàng "${created.name}" vào hệ thống.'),
        ),
      );

      return created;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lưu nhà hàng thất bại: $e')),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tạo markers từ danh sách _places
    final markers = <Marker>[
      for (final p in _places)
        Marker(
          point: LatLng(p.lat!, p.lon!),
          child: GestureDetector(
            onTap: () => _openPlaceSheet(p),
            child: const Icon(
              Icons.location_on,
              color: Colors.red,
              size: 36,
            ),
          ),
        ),
      if (_picked != null)
        Marker(
          point: _picked!,
          child: const Icon(Icons.push_pin, color: Colors.green, size: 28),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map - Nominatim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: () => _searchNearby(
              center: _defaultCenter,
              keyword: _searchCtrl.text.trim(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ====== Thanh tìm kiếm (keyword) ======
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nhập từ khoá (vd: restaurant, cafe, …)',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (q) => _searchNearby(
                      center: _defaultCenter,
                      keyword: q.trim(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () => _searchNearby(
                    center: _defaultCenter,
                    keyword: _searchCtrl.text.trim(),
                  ),
                  child: _loading
                      ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Tìm'),
                ),
              ],
            ),
          ),

          // ====== Bản đồ ======
          Expanded(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 13,
                onTap: (tapPos, latLng) => _reverseAt(latLng),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.queueapp',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),

          // ====== Thanh thông tin ngắn khi user tap vị trí ======
          if (_picked != null)
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Row(
                children: [
                  const Icon(Icons.place, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pickedAddress ??
                          '(${_picked!.latitude.toStringAsFixed(5)}, '
                              '${_picked!.longitude.toStringAsFixed(5)})',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: xử lý "Dùng vị trí này" → tuỳ flow của bạn
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Dùng vị trí'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Bottom sheet hiển thị chi tiết 1 địa điểm từ Nominatim
  void _openPlaceSheet(_Place p) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.primaryName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                p.name,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.category,
                      size: 18, color: Colors.black54),
                  const SizedBox(width: 6),
                  Text(
                    '${p.category}/${p.type}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // 👉 Nút Lưu & Xếp hàng
                  ElevatedButton.icon(
                    onPressed: () async {
                      // 1. Lưu vào DB
                      final saved = await _savePlaceToRestaurant(p);
                      if (saved == null) return;

                      if (!mounted) return;
                      Navigator.pop(context); // đóng bottom sheet

                      // 2. Điều hướng sang trang queue (QueueBookingScreen)
                      //    để đặt chỗ cho nhà hàng vừa lưu
                      Navigator.pushNamed(
                        context,
                        '/queue',
                        arguments: {
                          'restaurantId': saved.restaurantID,
                          'distanceKm': null,
                          'fromSearch': false,
                          // có thể truyền thêm lat/lon nếu bạn muốn
                          'lat': saved.latitude,
                          'lon': saved.longitude,
                          'restaurantName': saved.name,
                          'placeAddress': saved.address,
                        },
                      );
                    },
                    icon: const Icon(Icons.people),
                    label: const Text('Lưu & Xếp hàng'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Đóng'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Model đơn giản đại diện cho một địa điểm từ Nominatim
class _Place {
  final String name;     // display_name đầy đủ
  final double? lat;
  final double? lon;
  final String category; // vd: place, amenity, shop...
  final String type;     // vd: restaurant, cafe...

  _Place({
    required this.name,
    required this.lat,
    required this.lon,
    required this.category,
    required this.type,
  });

  /// Lấy tên ngắn (phần đầu trước dấu phẩy) để hiển thị đẹp
  String get primaryName {
    final idx = name.indexOf(',');
    if (idx <= 0) return name;
    return name.substring(0, idx).trim();
  }
}
