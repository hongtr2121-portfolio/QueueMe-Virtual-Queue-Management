// lib/main.dart
import 'package:flutter/material.dart';
import 'package:queueapp/AppGate.dart';
import 'package:queueapp/ui_pages/signup.dart';
import 'package:queueapp/ui_pages/splash.dart';
import 'package:queueapp/ui_pages/login.dart';
import 'package:queueapp/feature/users/home.dart';
import 'package:queueapp/feature/admin/admin.dart';
import 'package:queueapp/feature/admin/admin_gate.dart';
import 'package:queueapp/feature/users/map_page.dart';
import 'package:queueapp/feature/users/search_screen.dart';
import 'package:queueapp/feature/queue/queue_booking_screen.dart';
import 'package:queueapp/feature/users/profile.dart';
import 'package:queueapp/feature/queue/queue_ticket_screen.dart';
import 'package:queueapp/feature/admin/admin_store_screen.dart';
import 'package:queueapp/feature/admin/admin_queue_types_screen.dart';
// ✅ import gate mới, KHÔNG import NotificationsPage trực tiếp ở đây
import 'package:queueapp/feature/notifications/notifications_gate.dart';
import 'package:queueapp/feature/admin/reports_screen.dart';
import 'package:queueapp/feature/users/restaurant_review_screen.dart';


void main() => runApp(const Main());

class Main extends StatelessWidget {
  const Main({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/gate',
      routes: {
        '/gate': (_) => const AppGate(),
        '/welcome': (_) => const SplashWelcome(),
        '/signup': (_) => const SignUpPage(),
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomeScreen(),
        '/admin': (_) => const AdminGate(),
        '/map': (_) => const MapPage(),
        '/search': (_) => const SearchScreen(),
        '/queue': (_) => const QueueBookingScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/ticket': (_) => const QueueTicketScreen(),

        '/notifications': (_) => const NotificationsGate(),
        '/admin/restaurants': (_) => const AdminStoreScreen(),
        '/admin/notifications': (_) =>
        const Scaffold(
          body: Center(child: Text('Trang quản lý Thông báo (demo)')),
        ),
      },

      // ⭐ Thêm đoạn này vào
      onGenerateRoute: (settings) {
        if (settings.name == '/admin/reports') {
          final args = settings.arguments as Map<String, dynamic>;
          final int restaurantId = args['restaurantId'];

          return MaterialPageRoute(
            builder: (_) => ReportsScreen(restaurantId: restaurantId),
          );
        }

        if (settings.name == '/review') {
          final args = settings.arguments as Map<String, dynamic>;

          final int restaurantId = args['restaurantId'];
          final String restaurantName = (args['restaurantName'] ?? '').toString();
          final int queueEntryId = args['queueEntryId'];

          return MaterialPageRoute(
            builder: (_) => RestaurantReviewScreen(
              restaurantId: restaurantId,
              restaurantName: restaurantName,
              queueEntryId: queueEntryId,
            ),
          );
        }

        return null;
      },
    );
  }
  }
