import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:queueapp/api/auth_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:queueapp/api/api_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _storage = const FlutterSecureStorage();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  bool _obscure = true;
  bool _remember = false;
  bool _loading = false;
  String _userTypeSelected = 'Customer';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['userType'] is String) {
      _userTypeSelected = args['userType'] as String;
    }
  }

  Future<void> _doLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final res = await _auth.login(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );

      // ===== 1) Token =====
      final token = (res['token'] ?? res['accessToken'] ?? '').toString();
      if (token.isNotEmpty) {
        await ApiClient.instance.saveToken(token); // lưu key 'jwt'
      }

      // ===== 2) UserType =====
      String userType = (res['userType'] ?? '').toString().trim();
      if (userType.isEmpty) {
        // fallback: dùng userType đã chọn hoặc storage cũ (nếu có)
        userType = (await _storage.read(key: 'userType')) ?? _userTypeSelected;
      }
      if (userType.isEmpty) userType = 'Customer';
      await _storage.write(key: 'userType', value: userType);

      // ===== 3) userId / displayName / email =====
      String? userIdStr = res['userId']?.toString();
      String? displayName = res['displayName']?.toString();
      String? email = res['email']?.toString();

      // Nếu response thiếu -> decode JWT để lấy claim
      if ((userIdStr == null || userIdStr.isEmpty) && token.isNotEmpty) {
        final payload = JwtDecoder.decode(token);

        userIdStr = (payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] ??
            payload['sub'] ??
            payload['userId'] ??
            payload['id'])
            ?.toString();

        displayName ??=
            (payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'] ??
                payload['name'])
                ?.toString();

        email ??=
            (payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'] ??
                payload['email'])
                ?.toString();
      }

      // Cache lại để Home/Profile không bị id=null
      if (userIdStr != null && userIdStr.trim().isNotEmpty) {
        await _storage.write(key: 'userId', value: userIdStr.trim());
      }
      if (displayName != null && displayName.trim().isNotEmpty) {
        await _storage.write(key: 'displayName', value: displayName.trim());
      }
      if (email != null && email.trim().isNotEmpty) {
        await _storage.write(key: 'email', value: email.trim());
      }

      if (!mounted) return;

      // ===== 4) Điều hướng =====
      Navigator.pushNamedAndRemoveUntil(
        context,
        userType == 'Admin' ? '/admin' : '/home',
            (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng nhập thất bại: $msg')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Welcome',
                      style: TextStyle(
                        color: brown,
                        fontSize: (w * 0.09).clamp(22, 30).toDouble(),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 8,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: h * 0.45,
                          padding: const EdgeInsets.fromLTRB(16, 50, 16, 24),
                          decoration: BoxDecoration(
                            color: yellow,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _RoundedField(
                                  controller: _emailCtrl,
                                  hint: 'User Name or Email',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Nhập email';
                                    if (!v.contains('@')) return 'Email không hợp lệ';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _RoundedField(
                                  controller: _passCtrl,
                                  hint: 'Password',
                                  obscure: _obscure,
                                  suffix: IconButton(
                                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Switch(
                                      value: _remember,
                                      onChanged: (v) => setState(() => _remember = v),
                                      activeColor: green,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const Text('Remember me', style: TextStyle(fontSize: 12)),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () {},
                                      child: const Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          decoration: TextDecoration.underline,
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: 160,
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _doLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: green,
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
                                      'Login',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: h * 0.43,
                        left: 0,
                        right: 0,
                        child: Transform.translate(
                          offset: const Offset(0, -20),
                          child: Container(
                            height: h * 0.38,
                            padding: const EdgeInsets.fromLTRB(16, 50, 16, 24),
                            decoration: BoxDecoration(
                              color: green,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 10,
                                  offset: Offset(0, -2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text('Or log in with Email', style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 14),
                                _SocialButton(
                                  label: 'Log in with Google',
                                  asset: 'assets/google1.png',
                                  onTap: () {},
                                ),
                                const SizedBox(height: 12),
                                _SocialButton(
                                  label: 'Log in with Facebook',
                                  asset: 'assets/facebook.png',
                                  onTap: () {},
                                ),
                                const SizedBox(height: 16),
                                const Text("Don't have an account?", style: TextStyle(color: Colors.white)),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/welcome',
                                      arguments: {'userType': _userTypeSelected},
                                    );
                                  },
                                  child: const Text(
                                    'Sign up',
                                    style: TextStyle(
                                      color: Colors.white,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
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
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
