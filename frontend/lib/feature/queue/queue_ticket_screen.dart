import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:queueapp/api/queue_service.dart';
import 'package:queueapp/models/queue_ticket_args.dart';
import 'package:queueapp/models/queue_status.dart';
import 'package:queueapp/widgets/bottom_nav.dart';

// ✅ TODO: đổi đúng màn review của bạn
// import 'package:queueapp/screens/restaurant_review_screen.dart';

class QueueTicketScreen extends StatefulWidget {
  final QueueTicketArgs? args;
  const QueueTicketScreen({super.key, this.args});

  @override
  State<QueueTicketScreen> createState() => _QueueTicketScreenState();
}

class _QueueTicketScreenState extends State<QueueTicketScreen> {
  final _queueSvc = QueueService();
  final _storage = const FlutterSecureStorage();

  QueueTicketArgs? _args;
  Future<QueueStatus>? _statusFuture;
  Timer? _refreshTimer;

  bool _inited = false;
  bool _loadingActive = false;
  bool _canceling = false;

  int? _userId;

  /// SỐ THỨ TỰ ĐANG ĐƯỢC HIỂN THỊ (đã re-index từ backend)
  int? _displayYourNumber;

  // ✅ ADD
  String? _lastStatus;
  bool _finishing = false;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // -----------------------------------------
  // INIT + LOAD ARGS
  // -----------------------------------------
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_inited) return;
    _inited = true;

    _args = widget.args;

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (_args == null && routeArgs is QueueTicketArgs) {
      _args = routeArgs;
    }

    if (_args != null) {
      _setupRefresh(_args!.restaurantID);
    } else {
      _loadActiveTicket();
    }
  }

  // -----------------------------------------
  // SNACK
  // -----------------------------------------
  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // -----------------------------------------
  // LOAD ACTIVE TICKET
  // -----------------------------------------
  Future<void> _loadActiveTicket() async {
    setState(() => _loadingActive = true);

    try {
      final uid = await _storage.read(key: "userId");
      final display = await _storage.read(key: "displayName");

      if (uid == null) {
        setState(() => _loadingActive = false);
        return;
      }

      final userId = int.parse(uid);
      _userId = userId;

      final entry = await _queueSvc.getActiveTicket(userId: userId);

      if (entry == null) {
        setState(() => _loadingActive = false);
        return;
      }

      final args = QueueTicketArgs(
        queueEntryID: entry.queueEntryID,
        restaurantID: entry.restaurantID,
        queueTypeID: entry.queueTypeID,
        customerName: display ?? "Bạn",
        serviceName: "Queue Services",
        facilityName: entry.restaurantName ?? "Restaurant #${entry.restaurantID}",
        dateText: entry.joinTime.toLocal().toString().split(" ").first,
        timeRange: "",
        yourNumber: entry.currentPosition ?? 0,
        partySize: entry.partySize,
        estimatedMinutes: entry.estimatedWaitTime ?? 0,
      );

      setState(() {
        _args = args;
        _loadingActive = false;
      });

      _setupRefresh(args.restaurantID);
    } catch (e) {
      setState(() => _loadingActive = false);
    }
  }

  // -----------------------------------------
  // REFRESH STATUS
  // -----------------------------------------
  void _setupRefresh(int restaurantId) {
    Future<int?> ensureUserId() async {
      if (_userId != null) return _userId;
      final uid = await _storage.read(key: "userId");
      if (uid == null) return null;
      _userId = int.tryParse(uid);
      return _userId;
    }

    // Load first time
    ensureUserId().then((uid) {
      if (!mounted || uid == null) return;
      if (_canceling) return;

      setState(() {
        _statusFuture = _queueSvc.getCurrentStatus(
          restaurantID: restaurantId,
          userID: uid,
        );
      });
    });

    // Periodic refresh
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 30),
          (_) async {
        if (_canceling) return;

        final uid = await ensureUserId();
        if (!mounted || uid == null) return;

        setState(() {
          _statusFuture = _queueSvc.getCurrentStatus(
            restaurantID: restaurantId,
            userID: uid,
          );
        });
      },
    );
  }

  // -----------------------------------------
  // CANCEL TICKET
  // -----------------------------------------
  Future<void> _onCancelTicketPressed() async {
    final args = _args;
    if (args == null || _canceling) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Huỷ vé hàng chờ?"),
        content: Text(
          "Bạn sẽ rời khỏi hàng chờ tại ${args.facilityName}.\n"
              "Thao tác này không thể hoàn tác.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Không"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Huỷ vé"),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _canceling = true);

    try {
      await _queueSvc.cancelTicket(queueEntryID: args.queueEntryID);

      _refreshTimer?.cancel();
      _refreshTimer = null;

      final uidStr = await _storage.read(key: "userId");
      final uid = int.tryParse(uidStr ?? "");
      if (uid != null) {
        await _queueSvc.getActiveTicket(userId: uid);
      }

      if (!mounted) return;

      setState(() {
        _args = null;
        _statusFuture = null;
        _displayYourNumber = null;
        _lastStatus = null; // ✅ ADD
        _canceling = false;
      });

      _showSnack("Đã huỷ vé và rời khỏi hàng chờ.");

      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      Navigator.pushReplacementNamed(context, "/queue");
    } catch (e) {
      if (!mounted) return;
      setState(() => _canceling = false);
      _showSnack("Huỷ vé thất bại. Vui lòng thử lại.");
    }
  }

  // -----------------------------------------
  // ✅ FINISH MEAL (DÙNG XONG)
  // -----------------------------------------
  Future<void> _onFinishPressed() async {
    final args = _args;
    if (args == null || _finishing) return;

    setState(() => _finishing = true);
    try {
      // ✅ update status -> Completed (dùng API sẵn có)
      await _queueSvc.updateStatus(args.queueEntryID, "Completed");

      if (!mounted) return;

      // ✅ mở màn đánh giá (bạn thay đúng route/screen review của bạn)
      // Ví dụ route:
      // Navigator.pushNamed(context, '/review', arguments: {...});
      //
      // Hoặc nếu bạn có screen:
      // final ok = await Navigator.push(context, MaterialPageRoute(
      //   builder: (_) => RestaurantReviewScreen(
      //     restaurantId: args.restaurantID,
      //     restaurantName: args.facilityName,
      //   ),
      // ));
      //
      // Ở đây mình để route-based cho dễ:
      await Navigator.pushNamed(
        context,
        '/review',
        arguments: {
          "restaurantId": args.restaurantID,
          "restaurantName": args.facilityName,
          "queueEntryId": args.queueEntryID,
        },
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/queue");
    } catch (_) {
      if (!mounted) return;
      _showSnack("Không thể cập nhật 'Dùng xong'. Vui lòng thử lại.");
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  // -----------------------------------------
  // MAIN UI
  // -----------------------------------------
  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFF8E6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Your Queue Ticket",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: BottomNav(
        currentIndex: -1,
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/home');
          if (index == 1) Navigator.pushReplacementNamed(context, '/queue');
          if (index == 2) Navigator.pushReplacementNamed(context, '/notifications');
          if (index == 3) Navigator.pushReplacementNamed(context, '/profile');
        },
        onCenterPressed: () {
          Navigator.pushReplacementNamed(context, '/ticket');
        },
      ),
    );
  }

  // -----------------------------------------
  // BODY
  // -----------------------------------------
  Widget _buildBody() {
    if (_args == null && _loadingActive) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_args == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Hiện chưa có vé hàng chờ nào.\nHãy đặt chỗ để bắt đầu.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final args = _args!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTopCard(args),
          const SizedBox(height: 16),
          _buildInfoChips(args),
          const SizedBox(height: 20),
          _buildQueueStatus(args),
          const SizedBox(height: 12),

          // ✅ ADD: nút dùng xong chỉ khi InService
          _buildFinishButtonIfNeeded(),

          const SizedBox(height: 16),
          _buildCancelButton(),
          const SizedBox(height: 24),
          const Text("Scan upon arriving:", style: TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          _buildQR(args),
        ],
      ),
    );
  }

  // ✅ ADD
  Widget _buildFinishButtonIfNeeded() {
    final st = (_lastStatus ?? '').toLowerCase();
    final canFinish = st == 'inservice';
    if (!canFinish) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _finishing ? null : _onFinishPressed,
        icon: _finishing
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.done_all),
        label: Text(_finishing ? "Đang cập nhật..." : "Dùng xong"),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2EAD4B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // -----------------------------------------
  // TOP CARD (SHOW MAIN NUMBER)
  // -----------------------------------------
  Widget _buildTopCard(QueueTicketArgs args) {
    final number = _displayYourNumber ?? args.yourNumber;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2EAD4B), Color(0xFF46C07A)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  args.customerName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Your Queue Number",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            "$number",
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            args.facilityName,
            style: const TextStyle(color: Colors.white70),
          )
        ],
      ),
    );
  }

  // -----------------------------------------
  // CHIPS
  // -----------------------------------------
  Widget _buildInfoChips(QueueTicketArgs a) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        children: [
          _chip(Icons.room_service, a.serviceName),
          _chip(Icons.calendar_today, a.dateText),
          _chip(Icons.group, "${a.partySize} guests"),
          _chip(Icons.timer_outlined, "${a.estimatedMinutes} minutes"),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  // -----------------------------------------
  // QUEUE STATUS
  // -----------------------------------------
  Widget _buildQueueStatus(QueueTicketArgs args) {
    if (_statusFuture == null) {
      return _errorBox("Không thể tải trạng thái hàng chờ.");
    }

    return FutureBuilder<QueueStatus>(
      future: _statusFuture!,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _loadingBox();
        }

        if (!snap.hasData || snap.hasError) {
          return _errorBox("Không thể tải trạng thái hàng chờ.");
        }

        final st = snap.data!;
        final current = st.currentNumber;

        // ✅ status from backend
        final status = st.status ?? "Waiting";

        // ✅ keep last status for rendering buttons
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_lastStatus != status && !_canceling) {
            setState(() => _lastStatus = status);
          }
        });

        final your = st.yourNumber != 0 ? st.yourNumber : args.yourNumber;
        final ahead = st.ahead;
        final est = st.estimatedWait;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _displayYourNumber != your && !_canceling) {
            setState(() => _displayYourNumber = your);
          }
        });

        final isNow = ahead == 0;

        final nearby = List<int>.generate(9, (i) => your - 3 + i)
            .where((n) => n > 0)
            .toList();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _infoStat("Current", "$current", Colors.green),
                  const SizedBox(width: 10),
                  _infoStat("Your No.", "$your", Colors.blue),
                  const SizedBox(width: 10),
                  _infoStat("Ahead", "$ahead", Colors.orange),
                ],
              ),
              const SizedBox(height: 12),

              // ✅ show status (nhẹ)
              Text(
                "Status: $status",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time_filled,
                    color: isNow ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isNow
                          ? "Dự kiến đến lượt ngay bây giờ."
                          : "Dự kiến chờ khoảng $est phút.",
                      style: TextStyle(
                        color: isNow ? Colors.green : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "Nearby numbers:",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: nearby.map((n) {
                  final isYou = n == your;
                  final isDone = n < current;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isYou
                          ? Colors.blue.shade50
                          : isDone
                          ? Colors.grey.shade300
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isYou
                            ? Colors.blue
                            : isDone
                            ? Colors.grey
                            : Colors.green,
                      ),
                    ),
                    child: Text(
                      "$n",
                      style: TextStyle(
                        fontWeight: isYou ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoStat(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------
  // CANCEL BUTTON
  // -----------------------------------------
  Widget _buildCancelButton() {
    // ✅ OPTIONAL: đã InService/Completed thì ẩn cancel cho hợp logic
    final st = (_lastStatus ?? '').toLowerCase();
    if (st == 'inservice' || st == 'completed') {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _canceling ? null : _onCancelTicketPressed,
        icon: _canceling
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.cancel_outlined),
        label: Text(_canceling ? "Đang huỷ..." : "Huỷ vé / Rời hàng chờ"),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: BorderSide(color: Colors.red.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // -----------------------------------------
  // QR CODE (DÙNG SỐ RE-INDEX)
  // -----------------------------------------
  Widget _buildQR(QueueTicketArgs args, [double size = 240]) {
    final number = _displayYourNumber ?? args.yourNumber;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: QrImageView(
        data: "QUEUE-${args.queueEntryID}-${args.restaurantID}-$number",
        size: size,
      ),
    );
  }

  // -----------------------------------------
  // HELPERS
  // -----------------------------------------
  Widget _loadingBox() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Center(child: CircularProgressIndicator()),
  );

  Widget _errorBox(String text) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(text, style: const TextStyle(color: Colors.red)),
  );
}
