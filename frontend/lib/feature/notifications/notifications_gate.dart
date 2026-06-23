// lib/feature/notifications/notifications_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:queueapp/feature/notifications/notification_screen.dart'; // 👈 đổi import

class NotificationsGate extends StatefulWidget {
  const NotificationsGate({super.key});

  @override
  State<NotificationsGate> createState() => _NotificationsGateState();
}

class _NotificationsGateState extends State<NotificationsGate> {
  final _storage = const FlutterSecureStorage();
  int? _userId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final raw = await _storage.read(key: 'userId');
      final uid = int.tryParse(raw ?? '');

      if (!mounted) return;

      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng đăng nhập để xem thông báo.')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        setState(() {
          _userId = uid;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không đọc được thông tin người dùng.')),
      );
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // 👉 Dùng NotificationScreen làm UI chính
    return NotificationScreen(userId: _userId!);
  }
}
