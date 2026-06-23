class User {
  final int userID;
  final String email;
  final String? firstName;
  final String? lastName;
  final String userType;
  final bool isVerified;

  User({
    required this.userID,
    required this.email,
    this.firstName,
    this.lastName,
    required this.userType,
    required this.isVerified,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userID: (json['userID'] ?? json['UserID'] ?? 0) as int,
      email: (json['email'] ?? json['Email'] ?? '') as String,
      firstName: json['firstName'] ?? json['FirstName'],
      lastName: json['lastName'] ?? json['LastName'],
      userType: (json['userType'] ?? json['UserType'] ?? 'Customer') as String,
      isVerified:
      (json['isVerified'] ?? json['IsVerified'] ?? false) as bool,
    );
  }
}
