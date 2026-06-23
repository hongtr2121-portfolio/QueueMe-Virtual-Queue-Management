class TimeSeriesPoint {
  final DateTime date;
  final int count;

  TimeSeriesPoint({required this.date, required this.count});

  factory TimeSeriesPoint.fromJson(Map<String, dynamic> json) {
    return TimeSeriesPoint(
      date: DateTime.parse(json['date'] as String),
      count: json['count'] as int,
    );
  }
}

class HourCount {
  final int hour;
  final int count;

  HourCount({required this.hour, required this.count});

  factory HourCount.fromJson(Map<String, dynamic> json) {
    return HourCount(
      hour: json['hour'] as int,
      count: json['count'] as int,
    );
  }
}

class ReportsOverview {
  final int totalBookings;
  final int served;
  final int canceledOrNoShow;
  final double avgWaitingMinutes;
  final List<TimeSeriesPoint> bookingsPerDay;
  final List<TimeSeriesPoint> servedPerDay;
  final List<TimeSeriesPoint> canceledPerDay;
  final List<HourCount> peakHours;

  ReportsOverview({
    required this.totalBookings,
    required this.served,
    required this.canceledOrNoShow,
    required this.avgWaitingMinutes,
    required this.bookingsPerDay,
    required this.servedPerDay,
    required this.canceledPerDay,
    required this.peakHours,
  });

  factory ReportsOverview.fromJson(Map<String, dynamic> json) {
    List<dynamic> _list(dynamic v) => v as List<dynamic>? ?? [];

    return ReportsOverview(
      totalBookings: json['totalBookings'] as int,
      served: json['served'] as int,
      canceledOrNoShow: json['canceledOrNoShow'] as int,
      avgWaitingMinutes: (json['avgWaitingMinutes'] as num).toDouble(),
      bookingsPerDay: _list(json['bookingsPerDay'])
          .map((e) => TimeSeriesPoint.fromJson(e))
          .toList(),
      servedPerDay: _list(json['servedPerDay'])
          .map((e) => TimeSeriesPoint.fromJson(e))
          .toList(),
      canceledPerDay: _list(json['canceledPerDay'])
          .map((e) => TimeSeriesPoint.fromJson(e))
          .toList(),
      peakHours:
      _list(json['peakHours']).map((e) => HourCount.fromJson(e)).toList(),
    );
  }
}
