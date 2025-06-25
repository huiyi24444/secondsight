class ProfileModel {
  final String email;
  final String fullName;
  final bool isVerified;
  final String profilePic;
  final String username;
  final int phoneNum;
  final List<String> cart;
  final List<String> order;
  final List<String> recommendations;
  final List<String> wishlist;

  ProfileModel({
    required this.email,
    required this.fullName,
    required this.isVerified,
    required this.profilePic,
    required this.username,
    required this.phoneNum,
    required this.cart,
    required this.order,
    required this.recommendations,
    required this.wishlist,
  });

  // Convert a JSON object to ProfileModel
  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    // Handle phoneNum with type safety
    int parsePhoneNum(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        // This shouldn't happen in production, but handles legacy data
        final parsed = int.tryParse(value);
        if (parsed != null) {
          print('WARNING: phoneNum was stored as String, converting to int');
          return parsed;
        }
      }
      print('ERROR: Invalid phoneNum type: ${value.runtimeType}');
      return 0;
    }

    return ProfileModel(
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      isVerified: json['isVerified'] ?? false,
      profilePic: json['profilePic'] ?? '',
      username: json['username'] ?? '',
      phoneNum: parsePhoneNum(json['phoneNum']),
      cart: List<String>.from(json['cart'] ?? []),
      order: List<String>.from(json['order'] ?? []),
      recommendations: List<String>.from(json['recommendations'] ?? []),
      wishlist: List<String>.from(json['wishlist'] ?? []),
    );
  }

  // Convert ProfileModel to JSON object
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullName': fullName,
      'isVerified': isVerified,
      'profilePic': profilePic,
      'username': username,
      'phoneNum': phoneNum, // Always stored as int
      'cart': cart,
      'order': order,
      'recommendations': recommendations,
      'wishlist': wishlist,
    };
  }

  // Utility method to create a copy with updated fields
  ProfileModel copyWith({
    String? email,
    String? fullName,
    bool? isVerified,
    String? profilePic,
    String? username,
    int? phoneNum,
    List<String>? cart,
    List<String>? order,
    List<String>? recommendations,
    List<String>? wishlist,
  }) {
    return ProfileModel(
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      isVerified: isVerified ?? this.isVerified,
      profilePic: profilePic ?? this.profilePic,
      username: username ?? this.username,
      phoneNum: phoneNum ?? this.phoneNum,
      cart: cart ?? this.cart,
      order: order ?? this.order,
      recommendations: recommendations ?? this.recommendations,
      wishlist: wishlist ?? this.wishlist,
    );
  }
}