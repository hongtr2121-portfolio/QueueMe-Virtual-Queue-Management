  import 'package:flutter/material.dart';
  import 'package:flutter_secure_storage/flutter_secure_storage.dart';
  import 'package:jwt_decoder/jwt_decoder.dart';
  import 'package:queueapp/api/api_client.dart';
  import 'package:queueapp/widgets/bottom_nav.dart';

  class ProfileScreen extends StatefulWidget {
    const ProfileScreen({super.key});

    @override
    State<ProfileScreen> createState() => _ProfileScreenState();
  }

  class _ProfileScreenState extends State<ProfileScreen> {
    String? _name;
    String? _email;
    bool _loading = true;

    @override
    void initState() {
      super.initState();
      _loadUserInfo();
    }

    Future<void> _loadUserInfo() async {
      try {
        // 1) Đọc từ storage trước
        final storage = const FlutterSecureStorage();
        String? name = await storage.read(key: 'displayName');
        String? email = await storage.read(key: 'email');

        // 2) Nếu thiếu thì fallback sang JWT
        if (name == null || name.trim().isEmpty || email == null || email.trim().isEmpty) {
          final token = await ApiClient.instance.readToken();
          if (token != null && token.isNotEmpty) {
            final Map<String, dynamic> payload = JwtDecoder.decode(token);

            name = name ??
                payload[
                'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'
                ] as String?;
            email = email ??
                payload[
                'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'
                ] as String?;
          }
        }

        setState(() {
          _name = name;
          _email = email;
          _loading = false;
        });
      } catch (e) {
        setState(() {
          _loading = false;
        });
      }
    }

    Future<void> _logout(BuildContext context) async {
      // 1) clear token
      await ApiClient.instance.clearToken();

      // 2) clear toàn bộ secure storage (QUAN TRỌNG)
      const storage = FlutterSecureStorage();
      await storage.deleteAll();

      if (!mounted) return;

      // 3) reset stack
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }

    @override
    Widget build(BuildContext context) {
      const bg = Color(0xFFFFF8E6);

      final size = MediaQuery.of(context).size;
      final width = size.width;
      final isSmall = width < 360;

      double fs(double pct, {double min = 12, double max = 22}) =>
          (width * pct).clamp(min, max).toDouble();

      final titleSize = fs(0.05, min: 18, max: 22);
      final nameSize = fs(0.048, min: 16, max: 20);
      final itemSize = fs(0.042, min: 14, max: 16);

      final displayName = _name ?? 'Guest';
      final displayEmail = _email ?? 'Unknown email';

      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Profile',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: titleSize,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              isSmall ? 8 : 12,
              16,
              isSmall ? 8 : 16,
            ),
            child: Column(
              children: [
                // ===== Card avatar + tên/email =====
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundImage: AssetImage('assets/mat.jpg'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _loading
                            ? const SizedBox(
                          height: 24,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                            : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: nameSize,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ===== Card menu =====
                Expanded(
                  child: Container(
                    width: double.infinity,

                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _ProfileItem(
                          icon: Icons.person_outline,
                          title: 'Personal Info',
                          fontSize: itemSize,
                          onTap: () {},
                        ),
                        _ProfileItem(
                          icon: Icons.lock_outline,
                          title: 'Account & Security',
                          fontSize: itemSize,
                          onTap: () {},
                        ),
                        _ProfileItem(
                          icon: Icons.credit_card_outlined,
                          title: 'Payment',
                          fontSize: itemSize,
                          onTap: () {},
                        ),
                        _ProfileItem(
                          icon: Icons.notifications_none,
                          title: 'Notifications',
                          fontSize: itemSize,
                          onTap: () {},
                        ),
                        _ProfileItem(
                          icon: Icons.headset_mic_outlined,
                          title: 'Help & Support',
                          fontSize: itemSize,
                          onTap: () {},
                        ),
                        InkWell(
                          onTap: () => _logout(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.logout, color: Colors.red),
                                const SizedBox(width: 12),
                                Text(
                                  'Log out',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                    fontSize: itemSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 👇 GẮN BOTTOM NAV Ở ĐÂY
        bottomNavigationBar: BottomNav(
          currentIndex: 3, // tab Profile
          onTap: (index) {
            // TODO: đổi route cho khớp app của bạn
            if (index == 0) {
              Navigator.pushReplacementNamed(context, '/home');
            } else if (index == 1) {
              Navigator.pushReplacementNamed(context, '/queue');
            } else if (index == 2) {
              Navigator.pushReplacementNamed(context, '/notifications');
            } else if (index == 3) {
              // đang ở Profile rồi → không làm gì
            }
          },
          onCenterPressed: () {
            // TODO: route màn booking/queue của bạn
            Navigator.pushReplacementNamed(context, '/ticket');
          },
        ),
      );
    }
  }

  class _ProfileItem extends StatelessWidget {
    final IconData icon;
    final String title;
    final double fontSize;
    final VoidCallback? onTap;

    const _ProfileItem({
      required this.icon,
      required this.title,
      required this.fontSize,
      this.onTap,
    });

    @override
    Widget build(BuildContext context) {
      const arrowColor = Colors.black38;

      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.black87),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: arrowColor),
            ],
          ),
        ),
      );
    }
  }
