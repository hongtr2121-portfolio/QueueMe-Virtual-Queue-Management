// models/notification.dart
class AppNotification {
  final int notificationID;
  final String message;
  final String type;
  final DateTime timestamp;
  final bool isSent;
  final int userID;
  final int queueEntryID;

  AppNotification({
    required this.notificationID,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.isSent,
    required this.userID,
    required this.queueEntryID,
  });

  // Helper an toàn hơn: Trả về null nếu không tìm thấy key thay vì throw lỗi
  static T? _tryPick<T>(Map<String, dynamic> j, String camel, String pascal) {
    return (j[camel] ?? j[pascal]) as T?;
  }

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    // Parse an toàn, nếu null thì gán giá trị mặc định
    final idNum   = _tryPick<num>(j, 'notificationID', 'NotificationID') ?? 0;
    final userNum = _tryPick<num>(j, 'userID', 'UserID') ?? 0;
    final qeNum   = _tryPick<num>(j, 'queueEntryID', 'QueueEntryID') ?? 0;

    // Xử lý ngày tháng an toàn
    final dateStr = _tryPick<String>(j, 'timestamp', 'Timestamp');
    final date = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

    return AppNotification(
      notificationID: idNum.toInt(),
      message: _tryPick<String>(j, 'message', 'Message') ?? 'Không có nội dung',
      type: _tryPick<String>(j, 'type', 'Type') ?? 'Info',
      timestamp: date, // Chuyển sang giờ địa phương để hiển thị đúng giờ Việt Nam
      isSent: _tryPick<bool>(j, 'isSent', 'IsSent') ?? false,
      userID: userNum.toInt(),
      queueEntryID: qeNum.toInt(),
    );
  }
}