class Restaurant {
  final int? restaurantID;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? googlePlaceID;
  final double? overallRating;
  final String? operatingHours;
  final int? adminUserID;

  Restaurant({
    this.restaurantID,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.googlePlaceID,
    this.overallRating,
    this.operatingHours,
    this.adminUserID,
  });

  /// Đọc được cả camelCase lẫn PascalCase từ backend
  factory Restaurant.fromJson(Map<String, dynamic> j) {
    final idRaw = j['restaurantID'] ?? j['RestaurantID'];
    final nameRaw = j['name'] ?? j['Name'];
    final addrRaw = j['address'] ?? j['Address'];
    final latRaw = j['latitude'] ?? j['Latitude'];
    final lonRaw = j['longitude'] ?? j['Longitude'];
    final placeIdRaw = j['googlePlaceID'] ?? j['GooglePlaceID'];
    final ratingRaw = j['overallRating'] ?? j['OverallRating'];
    final hoursRaw = j['operatingHours'] ?? j['OperatingHours'];
    final adminRaw = j['adminUserID'] ?? j['AdminUserID'];

    return Restaurant(
      restaurantID: (idRaw as num?)?.toInt(),
      name: (nameRaw ?? '') as String,
      address: addrRaw as String?,
      latitude: (latRaw as num?)?.toDouble(),
      longitude: (lonRaw as num?)?.toDouble(),
      googlePlaceID: placeIdRaw as String?,
      overallRating: (ratingRaw as num?)?.toDouble(),
      operatingHours: hoursRaw as String?,
      adminUserID: (adminRaw as num?)?.toInt(),
    );
  }

  /// Dùng khi tạo mới từ app Admin / Map (nếu cần)
  /// - Vẫn giữ nguyên chữ ký để không lỗi chỗ gọi cũ
  Map<String, dynamic> toJsonForCreate(int adminUserID) => {
    'name': name,
    'address': address,
    'overallRating': overallRating,
    'adminUserID': adminUserID,
    'latitude': latitude,
    'longitude': longitude,
    'googlePlaceID': googlePlaceID,
    'operatingHours': operatingHours,
  }..removeWhere((k, v) => v == null);
}
