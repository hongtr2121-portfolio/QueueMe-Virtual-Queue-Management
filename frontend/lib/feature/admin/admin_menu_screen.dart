import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdminMenuScreen extends StatelessWidget {
  const AdminMenuScreen({super.key});

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
    const bg = Color(0xFFF5F7FB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Admin Menu',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 12),
            const ListTile(
              title: Text(
                'Chức năng',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const Divider(),

            // Dashboard
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              subtitle: const Text('Tổng quan hàng chờ & nhà hàng'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/admin');
              },
            ),

            // Store Settings
            ListTile(
              leading: const Icon(Icons.settings_suggest),
              title: const Text('Store Settings'),
              subtitle:
              const Text('Tạo / chỉnh sửa thông tin nhà hàng của bạn'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/store');
              },
            ),

            // Restaurant
            ListTile(
              leading: const Icon(Icons.storefront),
              title: const Text('Restaurants'),
              subtitle: const Text('Quản lý nhà hàng'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/restaurants');
              },
            ),

            // Queues
            ListTile(
              leading: const Icon(Icons.people_alt),
              title: const Text('Queues'),
              subtitle: const Text('Quản lý hàng chờ & gọi khách'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/queues');
              },
            ),

            // Notifications
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text('Notifications'),
              subtitle: const Text('Quản lý thông báo gửi khách'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/notifications');
              },
            ),

            const SizedBox(height: 20),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Đăng xuất',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}
