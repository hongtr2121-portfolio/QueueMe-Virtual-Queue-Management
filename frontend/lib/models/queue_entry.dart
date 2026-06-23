class QueueEntry {
  final int queueEntryID;
  final int restaurantID;
  final int userID;
  final int queueTypeID;
  final int partySize;
  final String status;
  final DateTime joinTime;
  final int? currentPosition;
  final int? estimatedWaitTime;
  final String? notes;
  final String? restaurantName;   // nếu có
  final int? queueNumber;         // nếu muốn dùng

  QueueEntry({
    required this.queueEntryID,
    required this.restaurantID,
    required this.userID,
    required this.queueTypeID,
    required this.partySize,
    required this.status,
    required this.joinTime,
    this.currentPosition,
    this.estimatedWaitTime,
    this.notes,
    this.restaurantName,
    this.queueNumber,
  });

  factory QueueEntry.fromJson(Map<String, dynamic> json) {
    return QueueEntry(
      queueEntryID: json['queueEntryID'] as int,
      restaurantID: json['restaurantID'] as int,
      userID: json['userID'] as int,
      queueTypeID: json['queueTypeID'] as int,
      partySize: json['partySize'] as int,
      status: json['status'] as String,
      joinTime: DateTime.parse(json['joinTime'] as String),
      currentPosition: json['currentPosition'] as int?,
      estimatedWaitTime: json['estimatedWaitTime'] as int?,
      notes: json['notes'] as String?,
      restaurantName: json['restaurantName'] as String?,
      queueNumber: json['queueNumber'] as int?,
    );
  }
}
