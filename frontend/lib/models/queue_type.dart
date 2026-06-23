class QueueType {
  final int queueTypeID;
  final int restaurantID;
  final String name;
  final int maxPartySize;
  final int standardServiceDuration;
  final bool isActive;

  QueueType({
    required this.queueTypeID,
    required this.restaurantID,
    required this.name,
    required this.maxPartySize,
    required this.standardServiceDuration,
    required this.isActive,
  });

  factory QueueType.fromJson(Map<String, dynamic> json) {
    int _readInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    bool _readBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v.toLowerCase() == 'true';
      return true;
    }

    return QueueType(
      queueTypeID:
      _readInt(json['queueTypeID'] ?? json['QueueTypeID'] ?? 0),
      restaurantID:
      _readInt(json['restaurantID'] ?? json['RestaurantID'] ?? 0),
      name: (json['name'] ?? json['Name'] ?? '') as String,
      maxPartySize:
      _readInt(json['maxPartySize'] ?? json['MaxPartySize'] ?? 0),
      standardServiceDuration: _readInt(
        json['standardServiceDuration'] ??
            json['StandardServiceDuration'] ??
            0,
      ),
      isActive: _readBool(json['isActive'] ?? json['IsActive'] ?? true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'queueTypeID': queueTypeID,
      'restaurantID': restaurantID,
      'name': name,
      'maxPartySize': maxPartySize,
      'standardServiceDuration': standardServiceDuration,
      'isActive': isActive,
    };
  }

  QueueType copyWith({
    int? queueTypeID,
    int? restaurantID,
    String? name,
    int? maxPartySize,
    int? standardServiceDuration,
    bool? isActive,
  }) {
    return QueueType(
      queueTypeID: queueTypeID ?? this.queueTypeID,
      restaurantID: restaurantID ?? this.restaurantID,
      name: name ?? this.name,
      maxPartySize: maxPartySize ?? this.maxPartySize,
      standardServiceDuration:
      standardServiceDuration ?? this.standardServiceDuration,
      isActive: isActive ?? this.isActive,
    );
  }
}
