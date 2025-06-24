class ProfileModel {
  String email;
  String fullName;
  bool isVerified;
  String profilePic;
  String username;
  int phoneNum;
  List<String> cart;
  List<String> order;
  List<String> recommendations;
  List<String> wishlist;

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
    return ProfileModel(
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      isVerified: json['isVerified'] ?? false,
      profilePic: json['profilePic'] ?? '',
      username: json['username'] ?? '',
      phoneNum: json['phoneNum'] ?? 0,
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
      'phoneNum': phoneNum,
      'cart': cart,
      'order': order,
      'recommendations': recommendations,
      'wishlist': wishlist,
    };
  }
}
