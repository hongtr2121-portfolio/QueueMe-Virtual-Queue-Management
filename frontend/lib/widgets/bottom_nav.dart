import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onCenterPressed;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCenterPressed,
  });

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF2EAD4B);

    return SafeArea(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ===== Background =====
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(context, Icons.home_rounded, 0),
                _navItem(context, Icons.restaurant_menu_rounded, 1),
                const SizedBox(width: 55), // chừa cho nút giữa
                _navItem(context, Icons.notifications_none_rounded, 2),
                _navItem(context, Icons.person_rounded, 3), // 👈 Profile
              ],
            ),
          ),

          // ===== Nút giữa =====
          Positioned(
            bottom: 19,
            child: GestureDetector(
              onTap: onCenterPressed,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brandGreen,
                  boxShadow: [
                    BoxShadow(
                      color: brandGreen.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Image.asset(
                    'assets/group.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, int index) {
    const Color active = Color(0xFF2EAD4B);
    const Color inactive = Colors.grey;

    final bool isActive = currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == 3) {
          // 👇 Khi bấm icon profile → sang trang Profile
          Navigator.pushNamed(context, '/profile');
          return;
        }
        onTap(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: isActive ? 30 : 26,
          color: isActive ? active : inactive,
        ),
      ),
    );
  }
}
