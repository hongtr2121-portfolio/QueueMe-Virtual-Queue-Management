import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:queueapp/api/api_client.dart';
import 'package:dio/dio.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});


  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  String _userType = 'Customer'; // mặc định tránh null
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Nhận dữ liệu userType từ màn trước (SplashWelcome)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['userType'] is String) {
      final incoming = args['userType'] as String; // 'Admin' / 'Customer'
      if (incoming != _userType) {
        setState(() => _userType = incoming); // cập nhật UI nếu bạn hiển thị role
      }
      debugPrint('🟢 Nhận được userType: $_userType');
    }
  }


  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  bool _agreeTos = false;
  bool _loading = false;

  // 🔹 Cấu hình API (đổi theo backend thật)
  static const String baseUrl = 'http://192.168.1.15:5266';
  static const String registerPath = '/api/users'; // khớp với UsersController

  // ================= Hàm đăng ký =================
  Future<void> _doSignUp() async {
    FocusScope.of(context).unfocus(); // ẩn bàn phím
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeTos) {
      _showSnack('⚠️ Bạn cần đồng ý với điều khoản sử dụng trước khi tiếp tục.');
      return;
    }

    setState(() => _loading = true);

    // ======= Chuẩn bị dữ liệu =======
    final payload = {
      "email": _emailCtrl.text.trim(),
      "phoneNumber": _phoneCtrl.text.trim(),
      "password": _passCtrl.text,
      "firstName": _firstNameCtrl.text.trim(),
      "lastName": _lastNameCtrl.text.trim(),
      "userType": _userType.trim(),
    };

    // ======= Kiểm tra đầu vào phía client (trước khi gửi server) =======
    if (payload["email"]!.isEmpty) {
      _showSnack('❌ Email không được để trống.');
      setState(() => _loading = false);
      return;
    }
    if (!payload["email"]!.contains('@')) {
      _showSnack('❌ Địa chỉ email không hợp lệ.');
      setState(() => _loading = false);
      return;
    }
    if (payload["password"]!.toString().length < 6) {
      _showSnack('❌ Mật khẩu phải có ít nhất 6 ký tự.');
      setState(() => _loading = false);
      return;
    }
    if (!RegExp(r'^[0-9]{9,11}$').hasMatch(payload["phoneNumber"]!)) {
      _showSnack('❌ Số điện thoại phải có từ 9–11 chữ số.');
      setState(() => _loading = false);
      return;
    }

    try {
      final uri = Uri.parse('http://192.168.1.15:5266/api/auth/register');
      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json; charset=utf-8"},
        body: jsonEncode(payload),
      );

      // ======= Phân tích phản hồi =======
      if (!mounted) return;

      if (res.statusCode == 201 || res.statusCode == 200) {
        _showSnack('✅ Đăng ký thành công!');
        Navigator.pushReplacementNamed(
          context,
          _userType.toLowerCase() == 'admin' ? '/admin' : '/home',
        );
      } else {
        // Khi server trả lỗi
        String msg = 'Đăng ký thất bại (HTTP ${res.statusCode})';
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body['message'] != null) {
            msg = '❌ ${body['message']}';
          } else if (body is Map && body['errors'] != null) {
            // Khi backend trả lỗi theo model validation .NET
            final firstError = (body['errors'] as Map).values.first;
            msg = '❌ ${firstError[0]}';
          }
        } catch (_) {}
        _showSnack(msg);
      }
    } catch (e) {
      _showSnack('🚫 Lỗi kết nối đến server: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF8E6);
    const yellow = Color(0xFFFFC107);
    const green = Color(0xFF2EAD4B);
    const brown = Color(0xFF8C6239);

    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== PHẦN 1: TIÊU ĐỀ =====
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Text(
                      "Let's Start",
                      style: TextStyle(
                        color: brown,
                        fontSize: (w * 0.09).clamp(22, 30),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // ===== PHẦN 2: STACK (vàng + xanh) =====
                Expanded(
                  flex: 9,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ===== KHỐI VÀNG =====
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: h * 0.2,
                          padding: const EdgeInsets.fromLTRB(16, 25, 20, 16),
                          decoration: BoxDecoration(
                            color: yellow,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _SocialButton(
                                label: 'Sign up with Google',
                                asset: 'assets/google1.png',
                                onTap: () {
                                  _showSnack('Google Sign-In chưa cấu hình');
                                },
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Or sign up with Email',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ===== KHỐI XANH (FORM) =====
                      Positioned(
                        top: h * 0.15,
                        left: 0,
                        right: 0,
                        child: Transform.translate(
                          offset: const Offset(0, -20),
                          child: Container(
                            height: h * 0.8,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: green,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 10,
                                  offset: Offset(0, -.5),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // ===== CÁC TRƯỜNG NHẬP =====
                                  _RoundedField(
                                    controller: _firstNameCtrl,
                                    hint: 'Enter first name',

                                    validator: (v) =>
                                    v == null || v.trim().isEmpty ? 'Nhập first name' : null,
                                  ),
                                  const SizedBox(height: 12),

                                  _RoundedField(
                                    controller: _lastNameCtrl,
                                    hint: 'Enter last name',
                                    validator: (v) =>
                                    v == null || v.trim().isEmpty ? 'Nhập last name' : null,
                                  ),
                                  const SizedBox(height: 12),

                                  _RoundedField(
                                    controller: _usernameCtrl,
                                    hint: 'Enter user name',
                                    validator: (v) =>
                                    v == null || v.trim().isEmpty ? 'Nhập username' : null,
                                  ),
                                  const SizedBox(height: 12),

                                  _RoundedField(
                                    controller: _emailCtrl,
                                    hint: 'Email',
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Nhập email';
                                      }
                                      if (!v.contains('@')) {
                                        return 'Email không hợp lệ';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  _RoundedField(
                                    controller: _phoneCtrl,
                                    hint: 'Phone number',
                                    keyboardType: TextInputType.phone,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Nhập số điện thoại';
                                      }
                                      if (!RegExp(r'^[0-9]{9,11}$').hasMatch(v)) {
                                        return 'Số điện thoại không hợp lệ';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  _RoundedField(
                                    controller: _passCtrl,
                                    hint: 'Password',
                                    obscure: _obscurePwd,
                                    suffix: IconButton(
                                      icon: Icon(_obscurePwd
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () =>
                                          setState(() => _obscurePwd = !_obscurePwd),
                                    ),
                                    validator: (v) =>
                                    v == null || v.isEmpty ? 'Nhập mật khẩu' : null,
                                  ),
                                  const SizedBox(height: 12),

                                  _RoundedField(
                                    controller: _confirmCtrl,
                                    hint: 'Confirm Password',
                                    obscure: _obscureConfirm,
                                    suffix: IconButton(
                                      icon: Icon(_obscureConfirm
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () =>
                                          setState(() => _obscureConfirm = !_obscureConfirm),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Nhập lại mật khẩu';
                                      if (v != _passCtrl.text) return 'Mật khẩu không khớp';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),

                                  // ===== CHECKBOX =====
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Checkbox(
                                        value: _agreeTos,
                                        onChanged: (v) =>
                                            setState(() => _agreeTos = v ?? false),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 0.5), // 👈 chỉnh nhẹ cho cân đối
                                        child: Text.rich(
                                          TextSpan(
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 11),
                                            children: [
                                              const TextSpan(
                                                  text: 'Tôi đồng ý với '),
                                              TextSpan(
                                                text: 'Điều khoản dịch vụ',
                                                style: const TextStyle(
                                                    color: Colors.yellow,
                                                    ),
                                              ),
                                              const TextSpan(text: ' và '),
                                              TextSpan(
                                                text: 'Chính sách bảo mật',
                                                style: const TextStyle(
                                                    color: Colors.yellow,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    ],
                                  ),
                                  const SizedBox(height: 0.5),

                                  // ===== NÚT ĐĂNG KÝ =====
                                  SizedBox(
                                    width: 180,
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _doSignUp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: yellow,
                                        shape: const StadiumBorder(),
                                        elevation: 0,
                                      ),
                                      child: _loading
                                          ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                          : const Text(
                                        'Create Account',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Already have an account?",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/login',
                                      );
                                    },
                                    child: const Text(
                                      'Log in',
                                      style: TextStyle(
                                        color: Colors.yellow,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),

                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================= Widgets phụ =================
class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _RoundedField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(24),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: validator,
        style: const TextStyle(
          fontSize: 13, // 👈 giảm cỡ chữ
        ),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String asset;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.asset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(asset, width: 20, height: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
