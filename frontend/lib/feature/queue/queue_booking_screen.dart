import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'package:queueapp/api/api_client.dart';
import 'package:queueapp/api/restaurant_service.dart';
import 'package:queueapp/api/queue_service.dart';
import 'package:queueapp/api/queue_type_service.dart';        // 👈 NEW
import 'package:queueapp/models/restaurant.dart';
import 'package:queueapp/models/queue_ticket_args.dart';
import 'package:queueapp/models/queue_type.dart';              // 👈 NEW
import 'package:queueapp/widgets/bottom_nav.dart';
import 'package:queueapp/feature/queue/queue_ticket_screen.dart';

class QueueBookingScreen extends StatefulWidget {
  const QueueBookingScreen({super.key});

  @override
  State<QueueBookingScreen> createState() => _QueueBookingScreenState();
}

class _QueueBookingScreenState extends State<QueueBookingScreen> {
  final _restaurantSvc = RestaurantService();
  final _queueSvc = QueueService();
  final _queueTypeSvc = QueueTypeService();                    // 👈 NEW
  final _storage = const FlutterSecureStorage();

  int? _userId;
  bool _saving = false;

  int? _restaurantId;
  double? _distanceKmArg;

  // QueueType liên quan
  int _maxPartySize = 10; // sẽ override bằng QueueTypes từ API

  // data từ DB
  Restaurant? _restaurant;
  bool _loadingInfo = true;
  String? _loadError;

  // QueueTypes từ DB
  List<QueueType> _queueTypes = [];
  bool _loadingQueueTypes = true;
  String? _queueTypeError;

  // ====== data tạm khi tới từ Search (chưa có trong DB) ======
  String? _pendingName;
  String? _pendingAddress;
  double? _pendingLat;
  double? _pendingLon;
  bool _fromSearch = false;

  // user hiển thị
  String _customerName = 'bạn';
  final String _serviceName = 'Queue Services';

  // ====== slot state ======
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  late Map<DateTime, List<TimeOfDay>> _slotsByDate;

  // ====== số người đặt bàn ======
  int _partySize = 2; // mặc định 2 người

  bool _initedArgs = false;

  @override
  void initState() {
    super.initState();

    final today = DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day);

    // Sinh khung giờ chuẩn 8h -> 22h, mỗi 1 tiếng
    List<TimeOfDay> _buildDaySlots() {
      const startHour = 8;
      const endHour = 22; // exclusive
      final list = <TimeOfDay>[];
      for (int h = startHour; h < endHour; h++) {
        list.add(const TimeOfDay(hour: 0, minute: 0).replacing(hour: h));
      }
      return list;
    }

    _slotsByDate = {
      _selectedDate: _buildDaySlots(),
      _selectedDate.add(const Duration(days: 1)): _buildDaySlots(),
    };

    // load user (userId + tên) từ storage / JWT
    _loadUserFromTokenAndStorage();
  }

  /// Lấy userId & tên: ưu tiên storage -> JWT
  Future<void> _loadUserFromTokenAndStorage() async {
    // 1) Từ SecureStorage
    final rawId = await _storage.read(key: 'userId');
    final storedName = await _storage.read(key: 'displayName');

    int? id = int.tryParse(rawId ?? '');
    String name = storedName ?? _customerName; // mặc định 'bạn'

    // 2) Fallback từ JWT nếu thiếu
    final token = await ApiClient.instance.readToken();
    if (token != null && token.isNotEmpty) {
      try {
        final payload = JwtDecoder.decode(token);

        final jwtName =
        payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name']
        as String?;

        if ((name == 'bạn' || name.trim().isEmpty) &&
            jwtName != null &&
            jwtName.trim().isNotEmpty) {
          name = jwtName.trim();
        }

        if (id == null) {
          final jwtId = payload['nameid'] ??
              payload[
              'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'];
          if (jwtId != null) {
            final parsed = int.tryParse(jwtId.toString());
            if (parsed != null) id = parsed;
          }
        }
      } catch (_) {
        // ignore lỗi decode
      }
    }

    if (!mounted) return;
    setState(() {
      _userId = id;
      _customerName = name;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initedArgs) return;
    _initedArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _restaurantId = args['restaurantId'] as int?;
      _distanceKmArg = (args['distanceKm'] as num?)?.toDouble();

      _fromSearch = args['fromSearch'] == true;
      _pendingName =
          args['restaurantName']?.toString() ?? args['placeName']?.toString();
      _pendingAddress = args['placeAddress']?.toString();
      _pendingLat = (args['lat'] as num?)?.toDouble();
      _pendingLon = (args['lon'] as num?)?.toDouble();

      final idFromArgs = args['userId'];
      if (idFromArgs != null) {
        final parsed = int.tryParse(idFromArgs.toString());
        if (parsed != null) _userId = parsed;
      }

      final maxPartyArg = args['maxPartySize'];
      if (maxPartyArg != null) {
        final parsed = int.tryParse(maxPartyArg.toString());
        if (parsed != null && parsed > 0) {
          _maxPartySize = parsed;
          if (_partySize > _maxPartySize) _partySize = _maxPartySize;
        }
      }
    }

    if (_restaurantId != null) {
      _fetchRestaurant();
    } else {
      setState(() {
        _loadingInfo = false;
        _loadingQueueTypes = false;
      });
    }
  }

  Future<void> _fetchRestaurant() async {
    setState(() {
      _loadingInfo = true;
      _loadError = null;
    });
    try {
      final r = await _restaurantSvc.getById(_restaurantId!);
      if (!mounted) return;
      setState(() {
        _restaurant = r;
        _loadingInfo = false;
      });

      await _loadQueueTypes(_restaurantId!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Không tải được thông tin nhà hàng: $e';
        _loadingInfo = false;
        _loadingQueueTypes = false;
      });
    }
  }

  /// Lấy danh sách QueueTypes từ backend
  Future<void> _loadQueueTypes(int restaurantId) async {
    setState(() {
      _loadingQueueTypes = true;
      _queueTypeError = null;
    });

    try {
      final list = await _queueTypeSvc.getByRestaurant(restaurantId);
      final active = list.where((e) => e.isActive).toList();

      int maxSize = 0;
      for (final qt in active) {
        if (qt.maxPartySize > maxSize) {
          maxSize = qt.maxPartySize;
        }
      }

      if (maxSize == 0) {
        maxSize = _maxPartySize; // fallback
      }

      setState(() {
        _queueTypes = active;
        _maxPartySize = maxSize;
        if (_partySize > _maxPartySize) {
          _partySize = _maxPartySize;
        }
      });
    } catch (e) {
      debugPrint('load queue types error: $e');
      setState(() {
        _queueTypeError = 'Không tải được loại bàn: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingQueueTypes = false);
      }
    }
  }

  /// Đảm bảo có restaurantId (từ DB hoặc tạo mới nếu tới từ search)
  Future<int> _ensureRestaurantId() async {
    if (_restaurantId != null) return _restaurantId!;

    if (_pendingName == null) {
      throw Exception('Thiếu thông tin nhà hàng để tạo mới.');
    }

    final created = await _restaurantSvc.create(
      name: _pendingName!,
      address: _pendingAddress,
      overallRating: null,
      adminUserId: null,
      // latitude: _pendingLat,
      // longitude: _pendingLon,
    );

    _restaurantId = created.restaurantID;
    return _restaurantId!;
  }

  /// Chọn QueueType phù hợp cho số khách hiện tại
  QueueType? _chooseQueueTypeForPartySize() {
    if (_queueTypes.isEmpty) return null;

    final candidates = _queueTypes
        .where((qt) => qt.maxPartySize >= _partySize && qt.isActive)
        .toList()
      ..sort((a, b) => a.maxPartySize.compareTo(b.maxPartySize));

    if (candidates.isEmpty) return null;
    return candidates.first;
  }

  // ================== slot helpers ==================
  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  String _monthName(int month) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month];
  }

  String _formatDate(DateTime d) {
    return '${_weekdayName(d.weekday)}, ${d.day} ${_monthName(d.month)} ${d.year}';
  }

  List<TimeOfDay> get _currentSlots {
    final key =
    DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return _slotsByDate[key] ?? [];
  }

  String _formatTimeLabel(TimeOfDay t) {
    final hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minuteStr = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:$minuteStr $period';
  }

  bool _isPastSlot(DateTime date, TimeOfDay slot) {
    final now = DateTime.now();
    final slotDateTime =
    DateTime(date.year, date.month, date.day, slot.hour, slot.minute);
    return !slotDateTime.isAfter(now);
  }

  Future<void> _pickAnotherDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _selectedTime = null;

        _slotsByDate.putIfAbsent(
          _selectedDate,
              () {
            final list = <TimeOfDay>[];
            for (int h = 8; h < 22; h++) {
              list.add(TimeOfDay(hour: h, minute: 0));
            }
            return list;
          },
        );
      });
    }
  }

  // ================== CONFIRM BOOKING ==================
  Future<void> _onConfirmBooking() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn giờ trước khi xác nhận.')),
      );
      return;
    }

    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thiếu userId – hãy chắc chắn đã đăng nhập.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // 1. Đảm bảo có restaurantId
      final restaurantId = await _ensureRestaurantId();

      // 2. Chọn QueueType phù hợp
      int? queueTypeId;
      if (_queueTypes.isNotEmpty) {
        final chosen = _chooseQueueTypeForPartySize();
        if (chosen == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Hiện không có loại bàn phù hợp cho $_partySize khách. '
                    'Vui lòng giảm số người hoặc liên hệ nhà hàng.',
              ),
            ),
          );
          return;
        }
        queueTypeId = chosen.queueTypeID;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nhà hàng chưa cấu hình loại bàn. Vui lòng thử lại sau.',
            ),
          ),
        );
        return;
      }

      // 3. Format time
      final startLabel = _formatTimeLabel(_selectedTime!);
      final endTime = TimeOfDay(
        hour: (_selectedTime!.hour + 1) % 24,
        minute: _selectedTime!.minute,
      );
      final endLabel = _formatTimeLabel(endTime);
      final timeRange = '$startLabel - $endLabel';
      final dateLabel = _formatDate(_selectedDate);

      // 4. Gọi API join queue
      final booking = await _queueSvc.join(
        restaurantID: restaurantId,
        userID: _userId!,
        queueTypeID: queueTypeId,
        partySize: _partySize,
        notes: 'Đặt chỗ lúc $startLabel ngày $dateLabel cho $_partySize người',
      );

      if (!mounted) return;

      // 5. Chuẩn bị dữ liệu gửi sang ticket screen
      final facilityNameLocal =
          _restaurant?.name ?? _pendingName ?? 'Restaurant';
      final facilityNameForTicket = booking.restaurantName ?? facilityNameLocal;

      final args = QueueTicketArgs(
        restaurantID: booking.restaurantID,
        queueTypeID: queueTypeId!,
        queueEntryID: booking.queueEntryID,
        customerName: _customerName,
        serviceName: _serviceName,
        facilityName: facilityNameForTicket,
        dateText: dateLabel,
        timeRange: timeRange,
        yourNumber: booking.currentPosition ?? booking.queueNumber ?? 0,
        partySize: booking.partySize,
        estimatedMinutes: booking.estimatedWaitTime, // 👈 LẤY TỪ BACKEND
      );

      // 6. Điều hướng sang ticket
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QueueTicketScreen(args: args),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi đặt chỗ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ================== BUILD ==================
  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF8E6);
    const green = Color(0xFF2EAD4B);

    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isSmall = width < 360;
    final isTablet = width >= 600;
    final rawTs = MediaQuery.textScaleFactorOf(context);
    final textScale = rawTs.clamp(1.0, 1.2);

    double fs(double pct, {double min = 11, double max = 22}) {
      return (width * pct).clamp(min, max).toDouble();
    }

    final appBarTitleSize = fs(0.05, min: 16, max: 20);
    final sectionTitleSize = fs(0.045, min: 15, max: 18);
    final buttonTextSize = fs(0.045, min: 14, max: 18);
    final horizontalPad = isTablet ? 24.0 : 16.0;

    final facilityName = _restaurant?.name ?? _pendingName ?? 'Loading...';

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale.toDouble()),
      ),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Select Slots',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: appBarTitleSize,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    8,
                    horizontalPad,
                    isTablet ? 24 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CustomerHeaderCard(
                        customerName: _customerName,
                        serviceName: _serviceName,
                        facilityName: facilityName,
                      ),
                      const SizedBox(height: 16),
                      if (_loadingInfo)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_loadError != null)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            _loadError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      else if (_restaurant != null)
                          _RestaurantInfoCard(
                            restaurant: _restaurant!,
                            distanceKm: _distanceKmArg,
                          )
                        else if (_pendingName != null)
                            _PendingPlaceCard(
                              name: _pendingName!,
                              address: _pendingAddress,
                              distanceKm: _distanceKmArg,
                            ),
                      SizedBox(height: isTablet ? 28 : 24),
                      Text(
                        'Number of Guests',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: sectionTitleSize,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _partySize > 1
                                ? () => setState(() => _partySize--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '$_partySize people',
                                style: TextStyle(
                                  fontSize: fs(0.05, min: 16, max: 20),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _partySize < _maxPartySize
                                ? () => setState(() => _partySize++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      Text(
                        'Maximum: $_maxPartySize people',

                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      if (_loadingQueueTypes)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (_queueTypeError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _queueTypeError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      SizedBox(height: isTablet ? 24 : 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Available Times',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: sectionTitleSize,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _pickAnotherDate,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: const Text('Select Date'),
                          ),
                        ],
                      ),
                      Text(
                        _formatDate(_selectedDate),
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: fs(0.035, min: 12, max: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TimeSlotSection(
                        date: _selectedDate,
                        slots: _currentSlots,
                        selectedTime: _selectedTime,
                        isPastSlot: _isPastSlot,
                        formatTime: _formatTimeLabel,
                        onSelect: (t) => setState(() => _selectedTime = t),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPad,
                  vertical: isSmall ? 10 : 12,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      padding: EdgeInsets.symmetric(
                        vertical: isSmall ? 12 : 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _saving ? null : _onConfirmBooking,
                    child: _saving
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                        : Text(
                      'Confirm Booking',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: buttonTextSize,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNav(
          currentIndex: 1,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacementNamed(context, '/home');
            } else if (index == 1) {
              Navigator.pushReplacementNamed(context, '/queue');
            } else if (index == 2) {
              Navigator.pushReplacementNamed(context, '/notifications');
            } else if (index == 3) {
              Navigator.pushReplacementNamed(context, '/profile');
            }
          },
          onCenterPressed: () {
            Navigator.pushNamed(context, '/ticket');
          },
        ),
      ),
    );
  }
}

// ===================== CÁC WIDGET PHỤ =====================
// ===================== CÁC WIDGET PHỤ =====================

class _CustomerHeaderCard extends StatelessWidget {
  final String customerName;
  final String serviceName;
  final String facilityName;

  const _CustomerHeaderCard({
    Key? key,
    required this.customerName,
    required this.serviceName,
    required this.facilityName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2EAD4B);
    const lightGreen = Color(0xFFEAF7ED);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.black54),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'Services :  ',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            serviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text(
                          'Facility  :  ',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            facilityName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more, color: Colors.black54),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: green,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantInfoCard extends StatelessWidget {
  final Restaurant restaurant;
  final double? distanceKm;

  const _RestaurantInfoCard({
    Key? key,
    required this.restaurant,
    this.distanceKm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2EAD4B);

    final addr = restaurant.address ?? 'Địa chỉ chưa cập nhật';
    final openText = restaurant.operatingHours ?? 'Weekday  •  24 hours';
    final hasAdmin = restaurant.adminUserID != null;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Private',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (hasAdmin)
                  const Icon(Icons.verified_user, size: 18, color: green),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              restaurant.name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.black54),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    addr,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (distanceKm != null)
                  Column(
                    children: [
                      const Icon(Icons.directions_walk,
                          size: 18, color: Colors.black54),
                      const SizedBox(height: 2),
                      Text(
                        '${distanceKm!.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Operating Hours',
                        style:
                        TextStyle(color: Colors.black54, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        openText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Icon(Icons.bar_chart, size: 18, color: green),
                      SizedBox(height: 4),
                      Text(
                        'Low',
                        style:
                        TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingPlaceCard extends StatelessWidget {
  final String name;
  final String? address;
  final double? distanceKm;

  const _PendingPlaceCard({
    Key? key,
    required this.name,
    this.address,
    this.distanceKm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final addr = address ?? 'Địa chỉ chưa rõ (từ bản đồ)';

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'From Map',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.black54),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    addr,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (distanceKm != null)
                  Column(
                    children: [
                      const Icon(Icons.directions_walk,
                          size: 18, color: Colors.black54),
                      const SizedBox(height: 2),
                      Text(
                        '${distanceKm!.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSlotSection extends StatelessWidget {
  final DateTime date;
  final List<TimeOfDay> slots;
  final TimeOfDay? selectedTime;
  final bool Function(DateTime, TimeOfDay) isPastSlot;
  final String Function(TimeOfDay) formatTime;
  final ValueChanged<TimeOfDay> onSelect;

  const _TimeSlotSection({
    Key? key,
    required this.date,
    required this.slots,
    required this.selectedTime,
    required this.isPastSlot,
    required this.formatTime,
    required this.onSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2EAD4B);

    if (slots.isEmpty) {
      return const Text(
        'Không còn slot trống cho ngày này.',
        style: TextStyle(color: Colors.black54),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final t in slots) _buildChip(t, green),
      ],
    );
  }

  Widget _buildChip(TimeOfDay t, Color green) {
    final disabled = isPastSlot(date, t);
    final selected = selectedTime != null &&
        selectedTime!.hour == t.hour &&
        selectedTime!.minute == t.minute;

    return ChoiceChip(
      label: Text(formatTime(t)),
      selected: selected,
      selectedColor: green,
      disabledColor: Colors.grey.shade300,
      labelStyle: TextStyle(
        color: disabled
            ? Colors.grey
            : (selected ? Colors.white : Colors.black87),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: disabled ? null : (_) => onSelect(t),
    );
  }
}

// ... (phần _CustomerHeaderCard, _RestaurantInfoCard, _PendingPlaceCard, _TimeSlotSection
//   giữ nguyên như file bạn gửi, vì không đụng tới estimated time / ahead)
