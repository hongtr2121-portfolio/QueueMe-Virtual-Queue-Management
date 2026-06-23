import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart'; // lấy GPS
import 'package:latlong2/latlong.dart' show LatLng, Distance, LengthUnit;
import 'package:queueapp/widgets/bottom_nav.dart';
import 'package:queueapp/api/user_service.dart';
// Gọi API lấy nhà hàng
import 'package:queueapp/api/restaurant_service.dart';
// 👇 NEW: dùng để reverse geocode lat/lon -> quận/huyện
import 'package:queueapp/api/nominatim_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:queueapp/feature/users/search_screen.dart';
import 'package:queueapp/api/api_client.dart';
import 'package:intl/intl.dart';
// 👇 NEW: dùng Dio gọi API history
import 'package:dio/dio.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = const FlutterSecureStorage();
  final _restaurantSvc = RestaurantService();
  final _nominatim = NominatimService(); // 👈 NEW: service gọi Nominatim
  final _userSvc = UserService();
  final Dio _dio = ApiClient.instance.dio; // 👈 NEW

  // ===== User info =====
  int? _userId;
  String? _userType;
  String _displayName = 'bạn';

  // ===== Location state =====
  LatLng? _myPos; // toạ độ hiện tại
  String? _locationText; // text hiện ở “location pill”
  bool _locDenied = false; // user từ chối quyền?

  // ===== UI state =====
  bool _loading = true; // load tổng trang
  bool _loadingNearby = false; // chỉ riêng phần “Near you”
  bool _loadingHistory = false; // 👈 NEW: loading cho history
  int _currentIndex = 0;
  final _searchCtrl = TextEditingController();

  // ===== Data =====
  List<_NearbyItem> _nearby = []; // sẽ build từ API + khoảng cách

  // 👇 NEW: list history động (không còn const)
  List<_HistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Khởi động: 1) resolve user  2) lấy GPS  3) load NearBy  4) load History
  Future<void> _boot() async {
    await _resolveUser();
    await _resolveLocation();
    await _loadNearby();

    // 👇 phải có dòng này
    _loadHistory();

    if (mounted) setState(() => _loading = false);
  }


  /// 1) Lấy user từ SecureStorage / JWT / arguments
  Future<void> _resolveUser() async {
    try {
      // 1) ƯU TIÊN: lấy từ SecureStorage (do AuthService đã lưu)
      final storedName     = await _storage.read(key: 'displayName');
      final storedUserId   = await _storage.read(key: 'userId');
      final storedUserType = await _storage.read(key: 'userType');

      String displayName = _displayName;                // mặc định = "bạn"
      int? userId        = _userId;
      String? userType   = _userType;

      if (storedName != null && storedName.trim().isNotEmpty) {
        displayName = storedName.trim();               // 👉 "First Last"
      }

      userId   ??= int.tryParse((storedUserId ?? '').trim());
      userType ??= storedUserType ?? 'Customer';

      // 2) Fallback: nếu vẫn chưa có tên thì đọc từ JWT
      if (displayName.trim().isEmpty || displayName == 'bạn') {
        final token = await ApiClient.instance.readToken();
        if (token != null && token.isNotEmpty) {
          final payload = JwtDecoder.decode(token);

          final claimName = payload[
          'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'
          ] as String?;

          if (claimName != null && claimName.trim().isNotEmpty) {
            displayName = claimName.trim();
          }
        }
      }

      // 3) Lấy thêm userId / userType từ arguments nếu có
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final argUserId = args['userId'];
        if (argUserId != null) {
          final parsed = int.tryParse(argUserId.toString());
          if (parsed != null) userId = parsed;
        }

        final argType = args['userType']?.toString();
        if (argType != null && argType.isNotEmpty) {
          userType = argType;
        }
      }

      if (!mounted) return;
      setState(() {
        _displayName = displayName;
        _userId      = userId;
        _userType    = userType;
      });

      // debug nhẹ
      // ignore: avoid_print
      print('Home _resolveUser -> name=$_displayName, id=$_userId, type=$_userType');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải thông tin người dùng: $e')),
      );
    }
  }

  /// 👉 Helper: reverse geocode lat/lon -> "Quận X, Thành phố Y"
  Future<String?> _getDistrictFromLatLng(double lat, double lon) async {
    try {
      final res = await _nominatim.reverseGeocode(lat, lon);
      if (res == null) return null;

      final address = res['address'] as Map<String, dynamic>?;
      if (address == null) return null;

      // Ở VN hay nằm trong các field này
      final district =
          address['city_district'] ?? address['district'] ?? address['suburb'];
      final city =
          address['city'] ?? address['town'] ?? address['state'] ?? address['region'];

      if (district != null && city != null) {
        return '$district, $city';
      }

      // fallback: dùng display_name nếu không tách được
      return res['display_name']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// 2) Xin quyền & lấy vị trí hiện tại (nếu người dùng cho phép)
  Future<void> _resolveLocation() async {
    try {
      // a) Kiểm tra dịch vụ location có bật chưa
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locDenied = true;
        _locationText = 'Location off'; // hiển thị gợi ý
        return;
      }

      // b) Quyền
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locDenied = true;
        _locationText = 'Permission denied';
        return;
      }

      // c) Lấy toạ độ (ưu tiên low power)
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      _myPos = LatLng(pos.latitude, pos.longitude);

      // d) 🔁 NEW: reverse geocode ra quận / thành phố
      final pretty =
      await _getDistrictFromLatLng(pos.latitude, pos.longitude);

      _locationText = pretty ?? 'Không xác định khu vực';
    } catch (_) {
      _locDenied = true;
      _locationText = 'Location unavailable';
    }
  }

  /// 3) Gọi API lấy danh sách nhà hàng gần bạn
  /// - Gồm CẢ quán trong database + quán lấy từ Nominatim (OSM)
  Future<void> _loadNearby() async {
    setState(() => _loadingNearby = true);

    try {
      final dist = Distance();
      final items = <_NearbyItem>[];

      // Helper tạo code 2 chữ cho badge (vd "Haidilao" -> "HA")
      String code2(String name) {
        final parts = name.trim().split(RegExp(r'\s+'));
        if (parts.length == 1) {
          final s = parts.first.toUpperCase();
          return s.length >= 2 ? s.substring(0, 2) : (s + ' ').substring(0, 2);
        }
        return (parts[0].isNotEmpty ? parts[0][0] : ' ') +
            (parts[1].isNotEmpty ? parts[1][0] : ' ');
      }

      // ===========================
      // 1) Nhà hàng trong DATABASE
      // ===========================
      try {
        final list = await _restaurantSvc.getRestaurants(
          page: 1,
          pageSize: 500,
        );

        // ignore: avoid_print
        print('Restaurants from API: ${list.length}');

        for (final r in list) {
          final lat = r.latitude;
          final lng = r.longitude;

          double? km;
          if (_myPos != null && lat != null && lng != null) {
            km = dist.as(LengthUnit.Kilometer, _myPos!, LatLng(lat, lng));
          }

          items.add(
            _NearbyItem(
              restaurantId: r.restaurantID,        // ✅ ID thật từ DB
              adminUserId: r.adminUserID,
              code: code2(r.name),
              name: r.name,
              distance: km != null
                  ? '${km.toStringAsFixed(km < 1 ? 2 : 1)} km'
                  : '--',
              distanceKm: km,
              lat: lat,                             // ✅ lưu lại toạ độ
              lon: lng,
              address: r.address,                   // nếu Restaurant có field này
            ),
          );
        }
      } catch (e) {
        // Không chết app, chỉ log
        // ignore: avoid_print
        print('Lỗi lấy nhà hàng từ API: $e');
      }

      // ===========================
      // 2) Quán gần đó từ Nominatim
      // ===========================
      if (_myPos != null) {
        try {
          final osmList = await _nominatim.searchNearby(
            lat: _myPos!.latitude,
            lon: _myPos!.longitude,
            keyword: 'restaurant',
            boxDelta: 0.03, // ~ vài km
            limit: 25,
          );

          for (final item in osmList) {
            final latStr = item['lat']?.toString();
            final lonStr = item['lon']?.toString();
            if (latStr == null || lonStr == null) continue;

            final lat = double.tryParse(latStr);
            final lon = double.tryParse(lonStr);
            if (lat == null || lon == null) continue;

            final display = item['display_name']?.toString() ?? '';
            final rawName = item['name']?.toString();
            final name = (rawName != null && rawName.isNotEmpty)
                ? rawName
                : (display.split(',').first.trim());

            final km = dist.as(
              LengthUnit.Kilometer,
              _myPos!,
              LatLng(lat, lon),
            );

            final address = display; // dùng nguyên display_name làm address text

            items.add(
              _NearbyItem(
                restaurantId: null,                     // 👈 chưa có trong DB
                adminUserId: null,
                code: code2(name),
                name: name,
                distance: '${km.toStringAsFixed(km < 1 ? 2 : 1)} km',
                distanceKm: km,
                lat: lat,                               // 👈 cần cho ensure-from-osm
                lon: lon,
                address: address,
              ),
            );
          }
        } catch (e) {
          // ignore: avoid_print
          print('Lỗi lấy dữ liệu từ Nominatim: $e');
        }
      }

      // ===========================
      // 4) Sắp xếp theo khoảng cách & lấy 10 quán gần nhất
      // ===========================
      items.sort((a, b) {
        final da = a.distanceKm;
        final db = b.distanceKm;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

      if (!mounted) return;
      setState(() {
        _nearby = items.take(10).toList();
        _loadingNearby = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingNearby = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được danh sách gần bạn: $e')),
      );
    }
  }

  /// 4) Gọi API lịch sử đặt bàn theo _userId
  Future<void> _loadHistory() async {
    print('[_loadHistory] _userId = $_userId');
    if (_userId == null) {
      return;
    }

    setState(() => _loadingHistory = true);

    try {
      // 🔥 GỌI ĐÚNG VỚI BACKEND: GET /api/QueueEntries/history/{userId}
      final resp = await _dio.get(
        '/QueueEntries/history/${_userId}',
      );

      print('[_loadHistory] status = ${resp.statusCode}');
      print('[_loadHistory] data = ${resp.data}');

      final data = resp.data;

      if (data is List) {
        final list = data
            .map((e) => _HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList();

        print('[_loadHistory] parsed history length = ${list.length}');

        if (!mounted) return;
        setState(() {
          _history = list;
        });
      } else {
        print('[_loadHistory] API không trả về List, kiểu: ${data.runtimeType}');
      }
    } catch (e, st) {
      print('[_loadHistory] ERROR = $e');
      print(st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được lịch sử đặt bàn: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  void _onNavTapped(int index) {
    setState(() => _currentIndex = index);
  }

  /// Khi bấm vào 1 nhà hàng trong "Near you"
  void _onNearbyTap(_NearbyItem item) async {
    int? restaurantId = item.restaurantId;

    // Nếu chưa có ID (quán chỉ từ Nominatim) -> gọi backend ensure-from-osm
    if (restaurantId == null) {
      if (item.lat == null || item.lon == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có toạ độ để tạo nhà hàng trong hệ thống.'),
          ),
        );
        return;
      }

      try {
        restaurantId = await _restaurantSvc.ensureFromOsm(
          name: item.name,
          latitude: item.lat!,
          longitude: item.lon!,
          address: item.address,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tạo/tìm nhà hàng trong hệ thống: $e'),
          ),
        );
        return;
      }
    }

    // Nếu vẫn không có ID thì chịu
    if (restaurantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không lấy được ID nhà hàng trong hệ thống.'),
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/queue',
      arguments: {
        'restaurantId': restaurantId,
        'restaurantName': item.name,
        'distanceKm': (item.distanceKm ?? 0).toDouble(),
      },
    );
  }

  void _onCenterPressed() {
    // Ví dụ: mở map
    // Navigator.pushNamed(context, '/map');
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF8E6);
    const brandGreen = Color(0xFF2EAD4B);
    const pillGreen = Color(0xFFE7F6EA);
    const darkText = Color(0xFF2C2C2C);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Responsive helpers
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 360;
    final rawTs = MediaQuery.textScaleFactorOf(context);
    final textScale = rawTs.clamp(1.0, 1.2);
    double fs(double pct, {double min = 12, double max = 28}) =>
        (width * pct).clamp(min, max).toDouble();
    final barHeight = isSmall ? 60.0 : 62.0;
    final helloName = _displayName ?? 'bạn';

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale.toDouble())),
      child: Scaffold(
        backgroundColor: bg,

        // ====== APP BAR MỚI ======
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(barHeight + 45),
          child: AppBar(
            backgroundColor: bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            toolbarHeight: barHeight + 30,
            titleSpacing: 20,
            title: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ----- Hello ----- //
                Text(
                  'Hello $helloName,',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: brandGreen,
                    fontSize: fs(0.2, min: 26, max: 32),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),

                // ----- Location pill ----- //
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width * 0.7,      // giới hạn chiều ngang pill
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmall ? 8 : 10,
                      vertical: isSmall ? 4 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: pillGreen,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.place, size: 16, color: Colors.green),
                        const SizedBox(width: 6),
                        Flexible(                        // tránh tràn text
                          child: Text(
                            _locationText ?? 'TP. HCM',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: fs(0.035, min: 12, max: 15),
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: isSmall ? 28 : 30,
                  child: const Icon(Icons.person),
                ),
              ),
            ],
          ),
        ),
        // ================== BODY ==================
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ----- Search box -----
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, isSmall ? 0 : 4, 16, 12),
                  child: TextField(
                    controller: _searchCtrl,
                    readOnly: true,                // 👈 không cho nhập ở đây
                    showCursor: false,
                    decoration: InputDecoration(
                      hintText: 'Searching',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isSmall ? 10 : 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onTap: () {
                      // 👉 mở trang search, truyền luôn location & toạ độ hiện tại
                      Navigator.pushNamed(
                        context,
                        '/search',
                        arguments: {
                          'locationText': _locationText,
                          'lat': _myPos?.latitude,
                          'lng': _myPos?.longitude,
                        },
                      );
                    },
                  ),
                ),
              ),

              // ----- Near you header -----
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Near you:',
                        style: TextStyle(
                          color: darkText,
                          fontSize: fs(0.045, min: 14, max: 18),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_loadingNearby) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                      if (_locDenied) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.info_outline,
                            size: 16, color: Colors.orange),
                      ],
                    ],
                  ),
                ),
              ),

              // ----- Near you list -----
              SliverToBoxAdapter(
                child: SizedBox(
                  height: isSmall ? 120 : 132,
                  child: _nearby.isEmpty
                      ? Center(
                    child: Text(
                      _locDenied
                          ? 'Không có quyền vị trí — đang hiển thị mặc định.'
                          : 'Không tìm thấy địa điểm gần bạn.',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  )
                      : LayoutBuilder(
                    builder: (context, constraints) {
                      final cardW = (width * 0.32).clamp(110, 160).toDouble();
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _nearby.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => SizedBox(
                          width: cardW,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _onNearbyTap(_nearby[i]),   // 👈 NHẤN Ở ĐÂY
                            child: _NearbyCard(
                              item: _nearby[i],
                              isSmall: isSmall,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ----- Appointment History -----
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'Appointment History:',
                    style: TextStyle(
                      color: darkText,
                      fontSize: fs(0.045, min: 14, max: 18),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // 👇 NEW: tuỳ state mà hiển thị
              if (_loadingHistory)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_history.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Chưa có lịch sử đặt bàn.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: _HistoryTile(item: _history[i]),
                    ),
                    childCount: _history.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),

        bottomNavigationBar: BottomNav(
          currentIndex: _currentIndex,
          onTap: _onNavTapped,
          onCenterPressed: () {
            Navigator.pushNamed(context, '/ticket');
          },
        ),
      ),
    );
  }
}

/// ===================== NEARBY =====================
class _NearbyItem {
  final int? restaurantId;      // có nếu lấy từ DB, null nếu chỉ từ Nominatim
  final int? adminUserId;
  final String code;
  final String name;
  final String distance;
  final double? distanceKm;

  // 👇 thêm để dùng cho ensure-from-osm
  final double? lat;
  final double? lon;
  final String? address;

  _NearbyItem({
    this.restaurantId,
    this.adminUserId,
    required this.code,
    required this.name,
    required this.distance,
    this.distanceKm,
    this.lat,
    this.lon,
    this.address,
  });

  bool get hasAdmin => adminUserId != null;
}

class _NearbyCard extends StatelessWidget {
  final _NearbyItem item;
  final bool isSmall;
  const _NearbyCard({required this.item, required this.isSmall});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2EAD4B);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 14 : 16, vertical: isSmall ? 10 : 14), // 🔥 dày hơn
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7ED),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Badge 2 chữ
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 14 : 18, vertical: isSmall ? 10 : 12), // 🔥 badge to hơn
            decoration: BoxDecoration(
              color: green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.code,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmall ? 18 : 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            item.distance,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// ===================== HISTORY =====================
class _HistoryItem {
  final String code, name, note, date, time;
  const _HistoryItem({
    required this.code,
    required this.name,
    required this.note,
    required this.date,
    required this.time,
  });

  factory _HistoryItem.fromJson(Map<String, dynamic> json) {
    final restaurantName = (json['restaurantName'] ?? '').toString();
    final note = (json['notes'] ?? '').toString();   // từ QueueHistoryDto.Notes
    final joinRaw = json['joinTime']?.toString();    // từ QueueHistoryDto.JoinTime

    DateTime? join;
    if (joinRaw != null && joinRaw.isNotEmpty) {
      join = DateTime.tryParse(joinRaw);
    }

    String dateStr = '';
    String timeStr = '';

    if (join != null) {
      dateStr = DateFormat('dd MMMM yyyy').format(join);
      timeStr = DateFormat('h:mm a').format(join);
    }

    // Tạo code 2 chữ từ tên nhà hàng
    String restaurantCode;
    final parts = restaurantName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final s = parts.first.toUpperCase();
      restaurantCode =
      s.length >= 2 ? s.substring(0, 2) : (s + ' ').substring(0, 2);
    } else {
      final first = parts[0].isNotEmpty ? parts[0][0] : ' ';
      final second = parts[1].isNotEmpty ? parts[1][0] : ' ';
      restaurantCode = (first + second).toUpperCase();
    }

    return _HistoryItem(
      code: restaurantCode,
      name: restaurantName,
      note: note.isNotEmpty ? note : 'No note',
      date: dateStr,
      time: timeStr,
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final _HistoryItem item;
  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge trái
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF2EAD4B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.code,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Nội dung
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),

                  // ⬇⬇⬇ 2 dòng date / time dùng Flexible để không bị tràn
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.black54),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.date,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule,
                              size: 16, color: Colors.black54),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.time,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/map');
              },
              icon: const Icon(Icons.map_outlined, color: Colors.black54),
              tooltip: 'Xem bản đồ',
            ),
          ],
        ),
      ),
    );
  }
}
