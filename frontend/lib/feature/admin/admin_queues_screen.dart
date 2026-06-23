import 'package:flutter/material.dart';
import 'package:queueapp/api/queue_service.dart';

class AdminQueuesScreen extends StatefulWidget {
  final int restaurantID; // nhận id nhà hàng từ AdminPage

  const AdminQueuesScreen({
    super.key,
    required this.restaurantID,
  });

  @override
  State<AdminQueuesScreen> createState() => _AdminQueuesScreenState();
}

class _AdminQueuesScreenState extends State<AdminQueuesScreen> {
  final _queueService = QueueService();

  late Future<List<Map<String, dynamic>>> _futureQueues;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _futureQueues = _queueService.getAdminQueues(
      restaurantId: widget.restaurantID,
    );
  }

  void _reload() {
    setState(() {
      _futureQueues = _queueService.getAdminQueues(
        restaurantId: widget.restaurantID,
        status: _selectedFilter == 'All' ? null : _selectedFilter,
      );
    });
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> list) {
    if (_selectedFilter == 'All') return list;
    final k = _selectedFilter.replaceAll(' ', '').toLowerCase();
    return list.where((e) {
      final s = (e['status'] ?? '').toString().replaceAll(' ', '').toLowerCase();
      return s == k;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC107),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'QUEUES',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureQueues,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Lỗi tải dữ liệu:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final data = snapshot.data ?? [];
                final list = _applyFilter(data);

                if (list.isEmpty) {
                  return const Center(child: Text('Không có ticket nào.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 24, thickness: 1),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return _buildTicketRow(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'Waiting', child: Text('Waiting')),
                    DropdownMenuItem(value: 'Called', child: Text('Called')),
                    DropdownMenuItem(
                        value: 'InService', child: Text('In Service')),
                    DropdownMenuItem(
                        value: 'Completed', child: Text('Completed')),
                    DropdownMenuItem(
                        value: 'Canceled', child: Text('Canceled')),
                    DropdownMenuItem(
                        value: 'NoShow', child: Text('No show')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedFilter = value);
                    _reload();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              // chỗ này sau muốn làm filter nâng cao thì thêm
            },
            child: const Text('Filter'),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketRow(Map<String, dynamic> item) {
    final id = (item['queueEntryID'] as num?)?.toInt() ?? 0;
    final partySize = (item['partySize'] as num?)?.toInt() ?? 0;
    final createdAtStr = item['joinTime']?.toString() ?? '';
    final status = item['status']?.toString() ?? '';
    final userId = item['userID']?.toString() ?? '';
    final userName = item['userName']?.toString();
    final displayName = (userName == null || userName.isEmpty)
        ? 'User #$userId'
        : userName;

    String timeStr = createdAtStr;
    try {
      final dt = DateTime.parse(createdAtStr);
      timeStr =
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFC107),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ticket #$id',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '• $partySize người',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'CreatedAt: $timeStr',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildStatusChip(id, status),
        ],
      ),
    );
  }

  Color _statusColor(String statusRaw) {
    switch (statusRaw) {
      case 'Waiting':
        return Colors.orange.shade200;
      case 'Called':
        return Colors.blue.shade200;
      case 'InService':
        return Colors.green.shade200;
      case 'Completed':
        return Colors.grey.shade300;
      case 'Canceled':
        return Colors.red.shade200;
      case 'NoShow':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  String _statusLabel(String statusRaw) {
    switch (statusRaw) {
      case 'Waiting':
        return 'Pending';
      case 'Called':
        return 'Called';
      case 'InService':
        return 'In Service';
      case 'Completed':
        return 'Completed';
      case 'Canceled':
        return 'Canceled';
      case 'NoShow':
        return 'No show';
      default:
        return statusRaw;
    }
  }

  /// Các trạng thái được phép chuyển tiếp, phải match rule backend
  List<String> _nextAllowedStatuses(String current) {
    switch (current) {
      case 'Waiting':
        return ['Called', 'InService', 'Completed', 'Canceled'];
      case 'Called':
        return ['InService', 'Completed', 'Canceled'];
      case 'InService':
        return ['Completed', 'Canceled'];
      case 'Completed':
      case 'Canceled':
      case 'NoShow':
      default:
        return []; // không cho đổi nữa
    }
  }

  Future<void> _showChangeStatusSheet(
      int id,
      String currentStatus,
      ) async {
    final options = _nextAllowedStatuses(currentStatus);

    if (options.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trạng thái này không thể thay đổi nữa.'),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Đổi trạng thái ticket',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              ...options.map((s) {
                return ListTile(
                  title: Text(_statusLabel(s)),
                  onTap: () => Navigator.pop(ctx, s),
                );
              }).toList(),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected == null) return;

    try {
      await _queueService.updateQueueStatus(
        queueEntryId: id,
        status: selected,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật sang trạng thái: ${_statusLabel(selected)}')),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật trạng thái: $e')),
      );
    }
  }

  Widget _buildStatusChip(int id, String statusRaw) {
    final label = _statusLabel(statusRaw);
    final bgColor = _statusColor(statusRaw);

    return GestureDetector(
      onTap: () => _showChangeStatusSheet(id, statusRaw),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
