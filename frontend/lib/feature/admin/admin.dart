  import 'package:flutter/material.dart';
  import 'package:flutter_secure_storage/flutter_secure_storage.dart';
  import 'package:queueapp/feature/admin/admin_queue_types_screen.dart';
  import 'package:queueapp/api/restaurant_service.dart';
  import 'package:queueapp/api/queue_service.dart';
  import 'package:queueapp/models/restaurant.dart';
  import 'package:queueapp/feature/admin/admin_queues_screen.dart';
  import 'package:queueapp/feature/admin/reports_screen.dart';

  class AdminPage extends StatefulWidget {
    const AdminPage({super.key, required this.userId});
    final int userId;

    @override
    State<AdminPage> createState() => _AdminPageState();
  }

  class _AdminPageState extends State<AdminPage> {
    final _restaurantSvc = RestaurantService();
    final _queueSvc = QueueService();

    bool _loadingStats = true;
    String? _error;

    int _totalRestaurants = 0;
    int _totalQueues = 0;
    int _waitingGuests = 0;
    int _calledGuests = 0;
    int _completedGuests = 0;

    Restaurant? _mainRestaurant;

    // 🔢 Số lượt chờ theo ngày (Mon–Sun), lấy từ DB
    List<int> _weeklyQueues = List.filled(7, 0);

    @override
    void initState() {
      super.initState();
      _loadStats();
    }

    Future<void> _loadStats() async {
      setState(() {
        _loadingStats = true;
        _error = null;
      });

      try {
        // 1️⃣ Lấy danh sách nhà hàng rồi lọc theo admin hiện tại
        final all = await _restaurantSvc.getRestaurants(page: 1, pageSize: 100);
        final mine = all.where((r) => r.adminUserID == widget.userId).toList();

        int totalRestaurants = mine.length;
        Restaurant? mainRestaurant =
        mine.isNotEmpty ? mine.first : null; // 1 admin ~ 1 nhà hàng

        int waiting = 0;
        int called = 0;
        int completed = 0;
        int totalQueues = 0;
        List<int> weeklyQueues = List.filled(7, 0);

        // 2️⃣ Nếu có nhà hàng chính → gọi stats
        if (mainRestaurant?.restaurantID != null) {
          final stats =
          await _restaurantSvc.getQueueStats(mainRestaurant!.restaurantID!);

          waiting = stats['waiting'] ?? 0;
          called = stats['called'] ?? 0;
          completed = stats['completed'] ?? 0;
          totalQueues = waiting + called + completed;

          // 3️⃣ NEW: lấy số lượt chờ theo ngày (Mon–Sun) từ DB
          // TODO: implement hàm này trong QueueService cho khớp API backend
          weeklyQueues =
          await _queueSvc.getWeeklyCounts(mainRestaurant.restaurantID!);
        }

        if (!mounted) return;
        setState(() {
          _mainRestaurant = mainRestaurant;
          _totalRestaurants = totalRestaurants;
          _waitingGuests = waiting;
          _calledGuests = called;
          _completedGuests = completed;
          _totalQueues = totalQueues;
          _weeklyQueues = weeklyQueues;
          _loadingStats = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _loadingStats = false;
        });
      }
    }

    // mở route con bằng named route
    void _open(BuildContext context, String route) {
      Navigator.of(context).pushNamed(route);
    }

    Future<void> _logout(BuildContext context) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      const storage = FlutterSecureStorage();
      await storage.delete(key: 'jwt');
      await storage.delete(key: 'userId');
      await storage.delete(key: 'userType');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng xuất thành công!')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      }
    }

    @override
    Widget build(BuildContext context) {
      // 🎨 Palette giống các màn trước
      const bgColor = Color(0xFFFFF7DC); // nền vàng kem
      const yellow = Color(0xFFFFC928); // appbar vàng
      const green = Color(0xFF2EAD4B); // primary xanh

      return Scaffold(
        backgroundColor: bgColor,
        // ❌ KHÔNG DÙNG DRAWER NỮA
        appBar: AppBar(
          elevation: 0,
          backgroundColor: yellow,
          title: const Text(
            'Admin Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadingStats ? null : _loadStats,
              tooltip: 'Reload',
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () => _logout(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên nhà hàng (nếu có)
                if (_mainRestaurant != null) ...[
                  Text(
                    _mainRestaurant!.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _mainRestaurant!.address ?? 'Địa chỉ chưa cập nhật',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_loadingStats)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Lỗi khi tải thống kê:\n$_error',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),

                // ======= Top stats cards =======
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Restaurants',
                        value: '$_totalRestaurants',
                        change: '',
                        icon: Icons.store_mall_directory,
                        color: green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Total Queues',
                        value: '$_totalQueues',
                        change: '',
                        icon: Icons.people_alt,
                        color: const Color(0xFF333333),
                        dark: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Waiting Guests',
                        value: '$_waitingGuests',
                        change: 'Called: $_calledGuests',
                        icon: Icons.hourglass_bottom,
                        color: const Color(0xFF333333),
                        dark: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Completed',
                        value: '$_completedGuests',
                        change: '',
                        icon: Icons.done_all,
                        color: yellow,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ======= Section: Management =======
                const Text(
                  'Management',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _ManagementCard(
                  title: 'Store Settings',
                  subtitle: 'Tạo / chỉnh sửa thông tin nhà hàng của bạn',
                  icon: Icons.settings_suggest,
                  color: green,
                  onTap: () {
                    if (_mainRestaurant == null || _mainRestaurant!.restaurantID == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bạn chưa có nhà hàng để cấu hình queue type'),
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminQueueTypesScreen(
                          restaurantID: _mainRestaurant!.restaurantID!,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _ManagementCard(
                  title: 'Restaurant',
                  subtitle: 'Quản lý nhà hàng (1 admin / 1 store)',
                  icon: Icons.storefront,
                  color: const Color(0xFF00A8E8),
                  onTap: () => _open(context, '/admin/restaurants'),
                ),
                const SizedBox(height: 10),
                _ManagementCard(
                  title: 'Queues',
                  subtitle: 'Xem, cập nhật, gọi khách cho hàng chờ',
                  icon: Icons.people_alt,
                  color: const Color(0xFFFFC400),
                  onTap: () {
                    if (_mainRestaurant == null || _mainRestaurant!.restaurantID == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bạn chưa có nhà hàng nào để xem hàng chờ'),
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminQueuesScreen(
                          restaurantID: _mainRestaurant!.restaurantID!, // 👈 truyền id thật
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _ManagementCard(
                  title: 'Notifications',
                  subtitle: 'Quản lý thông báo gửi đến khách',
                  icon: Icons.notifications_active,
                  color: const Color(0xFFFF6B6B),
                  onTap: () => _open(context, '/admin/notifications'),
                ),
                const SizedBox(height: 10),
                _ManagementCard(
                  title: 'Reports',
                  subtitle: 'Xem báo cáo tình hình kinh doanh, lượt khách, hiệu suất bàn',
                  icon: Icons.bar_chart,
                  color: const Color(0xFF6C63FF),
                  onTap: () {
                    // giống logic ở card Queues
                    if (_mainRestaurant == null || _mainRestaurant!.restaurantID == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bạn chưa có nhà hàng nào để xem báo cáo'),
                        ),
                      );
                      return;
                    }

                    final restaurantId = _mainRestaurant!.restaurantID!;

                    Navigator.pushNamed(
                      context,
                      '/admin/reports',
                      arguments: {
                        'restaurantId': restaurantId,
                      },
                    );
                  },
                ),

                const SizedBox(height: 20),

                // ======= Section: Today overview =======
                const Text(
                  'Today Overview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _WeeklyOverviewCard(values: _weeklyQueues),
              ],
            ),
          ),
        ),
      );
    }
  }

  /// Card thống kê nhỏ bên trên dashboard
  class _StatCard extends StatelessWidget {
    final String title;
    final String value;
    final String change;
    final IconData icon;
    final Color color;
    final bool dark;

    const _StatCard({
      required this.title,
      required this.value,
      required this.change,
      required this.icon,
      required this.color,
      this.dark = false,
    });

    @override
    Widget build(BuildContext context) {
      final bg = dark ? const Color(0xFF333333) : Colors.white;
      final iconBg = dark ? const Color(0xFF555555) : color;
      final textColor = dark ? Colors.white : Colors.black87;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                  const Icon(Icons.insert_chart, color: Colors.white, size: 20),
                ),
                const Spacer(),
                Icon(
                  Icons.more_horiz,
                  color: dark ? Colors.white54 : Colors.black26,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: dark ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
            if (change.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                change,
                style: TextStyle(
                  color: dark ? Colors.greenAccent : Colors.green,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

  /// Card "Management"
  class _ManagementCard extends StatelessWidget {
    final String title;
    final String subtitle;
    final IconData icon;
    final Color color;
    final VoidCallback onTap;

    const _ManagementCard({
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.onTap,
    });

    @override
    Widget build(BuildContext context) {
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      );
    }
  }

  /// Biểu đồ tuần: Mon–Sun giống card Tasks Overview
  class _WeeklyOverviewCard extends StatelessWidget {
    final List<int> values; // chiều dài 7

    const _WeeklyOverviewCard({required this.values});

    @override
    Widget build(BuildContext context) {
      // nếu dữ liệu không đủ 7 phần tử thì pad thêm 0
      final padded = List<int>.from(values);
      while (padded.length < 7) {
        padded.add(0);
      }
      final data = padded.take(7).toList();

      final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final int maxValue =
      data.isEmpty ? 0 : data.reduce((a, b) => a > b ? a : b);

      // cột nổi = cột có giá trị lớn nhất
      final int highlightIndex = maxValue == 0 ? 0 : data.indexOf(maxValue);

      const double maxBarHeight = 80;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tasks Overview',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Số lượt chờ theo ngày (Thứ 2 - Chủ nhật)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 130,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final value = data[index];
                  final label = labels[index];
                  final bool isHighlight = index == highlightIndex;

                  final double barHeight = maxValue == 0
                      ? 0
                      : (value / maxValue) * maxBarHeight;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isHighlight && value > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$value',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ] else
                        const SizedBox(height: 22),
                      Container(
                        width: 14,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: isHighlight
                              ? const Color(0xFFFFC928)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      );
    }
  }
