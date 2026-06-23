class QueueTicketArgs {
  final int queueEntryID;
  final int restaurantID;
  final int queueTypeID;
  final int yourNumber;        // số thứ tự đúng của bạn (queueNumber)
  final String customerName;
  final String serviceName;
  final String facilityName;
  final String dateText;
  final String timeRange;
  final int partySize;
  final int? estimatedMinutes;   // 👈 THÊM
// 👈 THÊM


  QueueTicketArgs({
    required this.queueEntryID,
    required this.restaurantID,
    required this.queueTypeID,
    required this.customerName,
    required this.serviceName,
    required this.facilityName,
    required this.dateText,
    required this.timeRange,
    required this.yourNumber,
    required this.partySize,
    this.estimatedMinutes,       //   THÊM
  });
}
