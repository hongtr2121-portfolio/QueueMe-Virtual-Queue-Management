import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:queueapp/feature/admin/admin.dart';

class AdminGate extends StatefulWidget {
  const AdminGate({super.key});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  final _storage = const FlutterSecureStorage();
  int? _userId;
  String? _userType;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final rawId = await _storage.read(key: 'userId');
      final rawType = (await _storage.read(key: 'userType'))?.toLowerCase();
      final jwt = await _storage.read(key: 'jwt');

      final uid = int.tryParse(rawId ?? '');
      debugPrint('[AdminGate] userId=$uid, userType=$rawType, jwt=${jwt != null}');

      if (!mounted) return;

      if (jwt == null || uid == null || rawType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng đăng nhập để vào khu vực quản trị.')),
        );
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      if (rawType != 'admin') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn không có quyền truy cập khu vực Admin.')),
        );
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }

      // ✅ Nếu tới đây thì hợp lệ, gán state
      setState(() {
        _userId = uid;
        _userType = rawType;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[AdminGate] error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xác định quyền truy cập.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ✅ Tới đây chắc chắn có userId
    return AdminPage(userId: _userId!);
  }
}
