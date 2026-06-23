class RestaurantReview {
  final int? reviewID;
  final int restaurantID;
  final int userID;
  final int rating; // 1..5
  final String? comment;
  final DateTime? createdAt;

  RestaurantReview({
    this.reviewID,
    required this.restaurantID,
    required this.userID,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'restaurantID': restaurantID,
    'userID': userID,
    'rating': rating,
    'comment': comment,
  }..removeWhere((k, v) => v == null);

  factory RestaurantReview.fromJson(Map<String, dynamic> j) => RestaurantReview(
    reviewID: (j['reviewID'] ?? j['ReviewID']) as int?,
    restaurantID: (j['restaurantID'] ?? j['RestaurantID']) as int,
    userID: (j['userID'] ?? j['UserID']) as int,
    rating: (j['rating'] ?? j['Rating']) as int,
    comment: (j['comment'] ?? j['Comment']) as String?,
    createdAt: j['createdAt'] != null
        ? DateTime.tryParse(j['createdAt'].toString())
        : null,
  );
}
