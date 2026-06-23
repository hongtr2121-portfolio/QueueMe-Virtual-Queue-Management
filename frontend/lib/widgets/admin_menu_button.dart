import 'package:flutter/material.dart';
import 'package:queueapp/feature/admin/admin_menu_screen.dart';

/// Icon 3 gạch dùng chung cho mọi màn Admin.
/// Dùng trong AppBar.leading:
/// leading: const AdminMenuButton(),
class AdminMenuButton extends StatelessWidget {
  const AdminMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu, color: Colors.black87),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminMenuScreen(),
          ),
        );
      },
    );
  }
}
