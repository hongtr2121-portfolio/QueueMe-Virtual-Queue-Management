import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api/api_client.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkTokenAndNavigate();
  }

  Map<String, dynamic> decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw const FormatException('Invalid JWT');
      final payload =
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return json.decode(payload) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _checkTokenAndNavigate() async {
    String nextRoute = '/login';

    final token = await ApiClient.instance.readToken();

    if (token != null && token.isNotEmpty) {
      try {
        // 1. ưu tiên lấy userType đã lưu trong storage
        String userType =
            (await _storage.read(key: 'userType'))?.toLowerCase() ?? '';

        // 2. nếu chưa có, thử đọc từ JWT
        if (userType.isEmpty) {
          final claims = decodeJwt(token);
          final roleClaim = (claims['role'] ??
              claims['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ??
              '')
              .toString()
              .toLowerCase();

          userType = roleClaim;
        }

        // 3. map sang route
        if (userType == 'admin') {
          nextRoute = '/admin';
        } else if (userType == 'customer') {
          nextRoute = '/home';
        } else {
          // nếu không rõ thì cứ cho vào Home như customer, KHÔNG xoá token
          nextRoute = '/home';
        }
      } catch (_) {
        // decode token lỗi thật sự thì mới clear
        await ApiClient.instance.clearToken();
        nextRoute = '/login';
      }
    }

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));
    Navigator.pushReplacementNamed(context, nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFF8E6),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF2EAD4B),
              strokeWidth: 3,
            ),
            SizedBox(height: 20),
            Text(
              'Checking session...',
              style: TextStyle(
                color: Color(0xFF2EAD4B),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
