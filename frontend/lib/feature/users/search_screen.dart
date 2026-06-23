import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance, LengthUnit;
import 'package:queueapp/api/restaurant_service.dart';
import 'package:queueapp/api/nominatim_service.dart'; // ✅ thêm

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final _restaurantSvc = RestaurantService();
  final _nominatimSvc = NominatimService(); // ✅ thêm

  LatLng? _myPos;
  String _locationText = 'TP. HCM, Tan Binh District';

  bool _loadingSuggested = true;
  List<_NearbyItem> _suggested = [];

  // ====== TRẠNG THÁI SEARCH PLACES (Nominatim) ======
  bool _searchLoading = false;
  String? _searchError;
  List<_SearchResultItem> _searchResults = [];
  Timer? _debounce;

  // demo search history & recent bookings
  final List<String> _historyTags = const [
    'pizza',
    'hotpot',
    'fast food',
    'pasta',
  ];

  final List<_BookingItem> _recentBookings = const [
    _BookingItem(
      title: 'Haidilao (Van Hanh Mall)',
      subtitle: '11 Su Van Hanh, 10 District, Ho Chi Minh City',
    ),
    _BookingItem(
      title: "Pizza 4P's (Vincom Plaza 3/2)",
      subtitle: 'Vincom Plaza, 3 thang 2 Street, 10 District, Ho Chi Minh City',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromArgs());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _initFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final loc = args['locationText']?.toString();
      final lat = args['lat'] as double?;
      final lng = args['lng'] as double?;
      if (loc != null && loc.trim().isNotEmpty) {
        _locationText = loc.trim();
      }
      if (lat != null && lng != null) {
        _myPos = LatLng(lat, lng);
      }
    }

    _loadSuggested();
  }

  Future<void> _loadSuggested() async {
    setState(() => _loadingSuggested = true);
    try {
      final list = await _restaurantSvc.getRestaurants(page: 1, pageSize: 500);

      // Nếu API không có dữ liệu -> fallback demo
      if (list.isEmpty) {
        _suggested = const [
          _NearbyItem(code: 'HA', name: 'Haidilao', distance: '1.8 km'),
          _NearbyItem(code: 'PZ', name: "Pizza 4P's", distance: '4.3 km'),
          _NearbyItem(code: 'HN', name: 'Hanuri', distance: '2.0 km'),
          _NearbyItem(code: 'GG', name: 'Gogi', distance: '1.9 km'),
          _NearbyItem(code: 'DK', name: 'Deokki', distance: '1.5 km'),
          _NearbyItem(code: 'KM', name: 'Kimura Ramen', distance: '2.1 km'),
          _NearbyItem(code: 'MW', name: 'Marwah', distance: '2.3 km'),
        ];
        return;
      }

      final dist = Distance();
      final items = <_NearbyItem>[];

      for (final r in list) {
        final lat = r.latitude;
        final lng = r.longitude;

        String code2(String name) {
          final parts = name.trim().split(RegExp(r'\s+'));
          if (parts.length == 1) {
            final s = parts.first.toUpperCase();
            return s.length >= 2 ? s.substring(0, 2) : (s + ' ').substring(0, 2);
          }
          return (parts[0].isNotEmpty ? parts[0][0] : ' ') +
              (parts[1].isNotEmpty ? parts[1][0] : ' ');
        }

        double? km;
        if (_myPos != null && lat != null && lng != null) {
          km = dist.as(LengthUnit.Kilometer, _myPos!, LatLng(lat, lng));
        }

        items.add(
          _NearbyItem(
            restaurantId: r.restaurantID,      // ✅ lấy từ DB
            adminUserId: r.adminUserID,
            code: code2(r.name),
            name: r.name,
            distance: km != null
                ? '${km.toStringAsFixed(km < 1 ? 2 : 1)} km'
                : '--',
            distanceKm: km,
          ),
        );
      }

      items.sort((a, b) {
        final da = a.distanceKm;
        final db = b.distanceKm;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

      _suggested = items.take(8).toList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được Suggested: $e')),
      );
      _suggested = const [];
    } finally {
      if (mounted) setState(() => _loadingSuggested = false);
    }
  }

  // ================== SEARCH PLACES (Nominatim) ==================

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = value.trim();
      if (q.isEmpty) {
        setState(() {
          _searchResults = [];
          _searchError = null;
          _searchLoading = false;
        });
      } else {
        _doSearch(q);
      }
    });
  }

  void _onSearchSubmitted(String value) {
    final q = value.trim();
    if (q.isEmpty) return;
    _doSearch(q);
  }

  double _deg2rad(double deg) => deg * pi / 180.0;

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _doSearch(String keyword) async {
    setState(() {
      _searchLoading = true;
      _searchError = null;
    });

    try {
      final center = _myPos ?? const LatLng(10.7769, 106.7009);

      final data = await _nominatimSvc.searchNearby(
        lat: center.latitude,
        lon: center.longitude,
        keyword: keyword,
        boxDelta: 0.05,
        limit: 20,
      );

      final results = <_SearchResultItem>[];

      for (final item in data) {
        final latStr = item['lat']?.toString();
        final lonStr = item['lon']?.toString();
        if (latStr == null || lonStr == null) continue;

        final lat = double.tryParse(latStr);
        final lon = double.tryParse(lonStr);
        if (lat == null || lon == null) continue;

        final displayName = item['display_name']?.toString() ?? '';
        final rawName = item['name']?.toString();
        String title;
        String subtitle;

        if (rawName != null && rawName.isNotEmpty) {
          title = rawName;
          subtitle = displayName;
        } else {
          final parts = displayName.split(',');
          title = parts.isNotEmpty ? parts.first.trim() : displayName;
          subtitle =
          parts.length > 1 ? parts.sublist(1).join(',').trim() : displayName;
        }

        double? km;
        if (_myPos != null) {
          km = _distanceKm(_myPos!.latitude, _myPos!.longitude, lat, lon);
        }

        results.add(
          _SearchResultItem(
            title: title,
            subtitle: subtitle,
            lat: lat,
            lon: lon,
            distanceKm: km,
          ),
        );
      }

      results.sort((a, b) {
        final da = a.distanceKm;
        final db = b.distanceKm;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      setState(() {
        _searchError = 'Có lỗi khi tìm kiếm: $e';
        _searchResults = [];
      });
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  void _onTapResult(_SearchResultItem item) {
    // Mở màn QueueBookingScreen với thông tin "tạm" từ Nominatim
    Navigator.pushNamed(
      context,
      '/queue',
      arguments: {
        'restaurantId': null,          // chưa có trong DB
        'restaurantName': item.title,  // tên hiển thị
        'placeAddress': item.subtitle, // địa chỉ đầy đủ
        'lat': item.lat,
        'lon': item.lon,
        'distanceKm': item.distanceKm,
        'fromSearch': true,            // flag để Queue biết là from search
      },
    );
  }

  /// ====== mở màn Queue cho 1 nhà hàng Suggested (có restaurantId) ======
  void _openQueueForRestaurant(_NearbyItem item) {
    if (item.restaurantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhà hàng demo, chưa có trong hệ thống.'),
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/queue',
      arguments: {
        'restaurantId': item.restaurantId,
        'restaurantName': item.name,
        'hasAdmin': item.hasAdmin,
        'distanceKm': item.distanceKm,
      },
    );
  }

  // ===============================================================

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF8E6);
    const pillGreen = Color(0xFFE7F6EA);
    const darkText = Color(0xFF2C2C2C);

    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isSmall = width < 360;
    double fs(double pct, {double min = 12, double max = 24}) =>
        (width * pct).clamp(min, max).toDouble();

    final isShowingSearchResults =
        _searchLoading || _searchResults.isNotEmpty || _searchError != null;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.place, color: Colors.green, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _locationText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: fs(0.04, min: 13, max: 16),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== Search box lớn =====
              TextField(
                controller: _searchCtrl,
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
                onChanged: _onSearchChanged,
                onSubmitted: _onSearchSubmitted,
              ),
              const SizedBox(height: 16),

              // ===== NẾU ĐANG SEARCH: HIỆN KẾT QUẢ =====
              if (isShowingSearchResults) ...[
                if (_searchLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_searchError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _searchError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                else if (_searchResults.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Không tìm thấy địa điểm nào.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  else ...[
                      Text(
                        'Results',
                        style: TextStyle(
                          color: darkText,
                          fontSize: fs(0.042, min: 14, max: 18),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final r in _searchResults) ...[
                        InkWell(
                          onTap: () => _onTapResult(r),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        r.distanceKm != null
                                            ? '${r.distanceKm!.toStringAsFixed(1)} km • ${r.subtitle}'
                                            : r.subtitle,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    ],
              ]
              // ===== NẾU KHÔNG SEARCH: HIỆN HISTORY + RECENT + SUGGESTED =====
              else ...[
                // ===== Search History =====
                Text(
                  'Search History:',
                  style: TextStyle(
                    color: darkText,
                    fontSize: fs(0.042, min: 14, max: 18),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final tag in _historyTags)
                      ActionChip(
                        label: Text(tag),
                        onPressed: () {
                          _searchCtrl.text = tag;
                          _onSearchSubmitted(tag);
                        },
                        backgroundColor: pillGreen,
                        labelStyle: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // ===== Recent Bookings =====
                Text(
                  'Your Recent Bookings',
                  style: TextStyle(
                    color: darkText,
                    fontSize: fs(0.042, min: 14, max: 18),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final b in _recentBookings) ...[
                  _RecentBookingTile(item: b),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 20),

                // ===== Suggested for You =====
                Row(
                  children: [
                    Text(
                      'Suggested for You',
                      style: TextStyle(
                        color: darkText,
                        fontSize: fs(0.042, min: 14, max: 18),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_loadingSuggested) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                if (_suggested.isEmpty && !_loadingSuggested)
                  const Text(
                    'Không có gợi ý nào.',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = width >= 360 ? 4 : 3;
                      final childW = (constraints.maxWidth -
                          12 * (crossAxisCount - 1)) /
                          crossAxisCount;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final item in _suggested)
                            SizedBox(
                              width: childW,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _openQueueForRestaurant(item),
                                child: _SuggestedCard(item: item),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============ Models UI ============

class _NearbyItem {
  final int? restaurantId;   // ✅ ID trong DB (nếu có)
  final int? adminUserId;    // ✅ null nếu không có admin
  final String code;
  final String name;
  final String distance;
  final double? distanceKm;

  const _NearbyItem({
    required this.code,
    required this.name,
    required this.distance,
    this.restaurantId,
    this.adminUserId,
    this.distanceKm,
  });

  bool get hasAdmin => adminUserId != null;
}

class _BookingItem {
  final String title;
  final String subtitle;
  const _BookingItem({required this.title, required this.subtitle});
}

class _SearchResultItem {
  final String title;
  final String subtitle;
  final double lat;
  final double lon;
  final double? distanceKm;

  const _SearchResultItem({
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lon,
    this.distanceKm,
  });
}

// ============ Widgets nhỏ ============

class _RecentBookingTile extends StatelessWidget {
  final _BookingItem item;
  const _RecentBookingTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.place, color: Colors.green),
      title: Text(
        item.title,
        style: const TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        item.subtitle,
        style: const TextStyle(color: Colors.black87),
      ),
      onTap: () {
        // TODO: mở lại booking / restaurant detail
      },
    );
  }
}

class _SuggestedCard extends StatelessWidget {
  final _NearbyItem item;
  const _SuggestedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2EAD4B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7ED),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.code,
              style: const TextStyle(
                color: Colors.white,
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
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
