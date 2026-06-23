class QueueStatus {
  final int currentNumber;
  final int yourNumber;
  final int ahead;
  final int estimatedWait;
  final String? status;

  QueueStatus({
    required this.currentNumber,
    required this.yourNumber,
    required this.ahead,
    required this.estimatedWait,
    required this.status,
  });

  factory QueueStatus.fromJson(Map<String, dynamic> json) {
    return QueueStatus(
      currentNumber: (json['currentNumber'] as num?)?.toInt() ?? 0,
      yourNumber: (json['yourNumber'] as num?)?.toInt() ?? 0,
      ahead: (json['ahead'] as num?)?.toInt() ?? 0,
      estimatedWait: (json['estimatedWait'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString(), // ✅ fixed (json, not j)
    );
  }
}
