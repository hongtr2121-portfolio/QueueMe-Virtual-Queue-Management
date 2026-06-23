// feature/notifications/notification_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:queueapp/api/notification_service.dart';
import 'package:queueapp/models/notification.dart';
import 'package:intl/intl.dart'; // Cần thêm package intl vào pubspec.yaml

class NotificationScreen extends StatefulWidget {
  final int userId;
  const NotificationScreen({super.key, required this.userId});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _service = NotificationService();
  List<AppNotification> _items = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    // ⏰ Tự động refresh mỗi 15 giây để xem có thông báo "Sắp đến lượt" không
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _fetch(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await _service.forUser(widget.userId);
      if (mounted) {
        setState(() {
          _items = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _loading = false);
        // Có thể hiện snackbar báo lỗi mạng
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetch(),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: () => _fetch(silent: true),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) => _buildItem(_items[i]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_active, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Bạn chưa có thông báo nào', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _fetch, child: const Text('Tải lại'))
        ],
      ),
    );
  }

  Widget _buildItem(AppNotification item) {
    // Format ngày giờ đẹp: 14:30 - 20/10/2023
    final timeStr = DateFormat('HH:mm - dd/MM').format(item.timestamp.toLocal());

    // Đổi màu nếu là loại thông báo quan trọng
    final isUrgent = item.type == 'AlmostTurn' || item.type == 'Called';

    return Card(
      elevation: isUrgent ? 4 : 1,
      color: isUrgent ? Colors.orange.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        side: isUrgent ? BorderSide(color: Colors.orange.shade300) : BorderSide.none,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          isUrgent ? Icons.notifications_active_rounded : Icons.notifications_active_rounded,
          color: isUrgent ? Colors.orange : Colors.green,
        ),
        title: Text(
          item.message,
          style: TextStyle(
            fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        onTap: () {
          // Bấm vào thì đánh dấu đã đọc (nếu backend hỗ trợ logic này)
          _service.markAsRead(item.notificationID);
        },
      ),
    );
  }
}