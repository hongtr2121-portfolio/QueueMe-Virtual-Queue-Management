import 'package:flutter/material.dart';
import 'dart:math' as math;

class SplashWelcome extends StatelessWidget {
  const SplashWelcome({super.key});



  // trong SplashWelcome
  void _goSignUp(BuildContext context, String userType) {
    Navigator.pushNamed(context, '/signup', arguments: {'userType': userType});
  }
// Nút Customer/Admin gọi _goSignUp(...)

  @override
  Widget build(BuildContext context) {
    // màu sắc gợi ý giống mock
    const bg = Color(0xFFFFF8E6);     // nền kem
    const green = Color(0xFF2EAD4B);  // nút Admin
    const yellow = Color(0xFFFFC107); // nút Customer
    const textGreen = Color(0xFF2EAD4B);

    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;

    // Thiết kế gốc tham chiếu (mobile phổ biến ~360x800)
    const baseW = 360.0;
    const baseH = 800.0;

    // Tính scale theo cả 2 chiều nhưng KẸP để không quá to/nhỏ
    final scaleW = (w / baseW).clamp(0.85, 1.15); // méo theo ngang
    final scaleH = (h / baseH).clamp(0.85, 1.15); // méo theo dọc
    final s = math.min(scaleW, scaleH);           // dùng scale “an toàn”

    // Giới hạn khung nội dung max 480 để máy lớn không giãn quá rộng
    final maxContentWidth = math.min(w, 480.0);

    // Kích thước theo scale + clamp
    final titleSize = (32.0 * s).clamp(22.0, 36.0);
    final btnWidth  = (maxContentWidth * 0.6).clamp(220.0, 320.0);
    final btnHeight = (h * 0.06).clamp(44.0, 56.0);
    final gapLarge  = (h * 0.05).clamp(20.0, 40.0);
    final gapMed    = (h * 0.03).clamp(14.0, 24.0);
    final gapSmall  = (h * 0.02).clamp(10.0, 18.0);

    // Dịch tiêu đề nhẹ theo tỉ lệ nhưng kẹp biên
    final dx = (-w * 0.015).clamp(-16.0, -6.0);   // trái 6~16px
    final dy = (-h * 0.02).clamp(-28.0, -10.0);   // lên 10~28px

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            // có thể thêm mây/đám mây nếu bạn có asset
            // 🌥️ MÂY (giữ đúng vị trí tương đối, không méo trên máy to/nhỏ)
            Positioned(
              top: 120,
              right:-20,
              child: Image.asset(
                'assets/mây 1.png', // đổi thành 'assets/may_1.png' nếu bạn đã rename
                width: 220,
              ),
            ),
            Positioned(
              top: 250,
              left: -20,
              child: Image.asset(
                'assets/mây 2.png', // đổi thành 'assets/may_2.png' nếu bạn đã rename
                width: 225,
              ),
            ),

            // nội dung chính
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                Transform.translate(
                  offset: const Offset(-40, -180),
                    child: Text(
                      'Welcome to\nQueueMe!',
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        color: textGreen,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
              ),
                    const SizedBox(height: 28),

                    // Nút Customer
                    SizedBox(
                      width: 220,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => _goSignUp(context, 'Customer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: yellow,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Customer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nút Admin
                    SizedBox(
                      width: 220,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => _goSignUp(context, 'Admin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                  ],
                ),
              ),
            ),
            Positioned(bottom: 20, right: 20, child: Image.asset('assets/táo chào.png', width: 250)),
          ],

        ),
      ),
    );
  }
}
