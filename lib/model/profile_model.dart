import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileModel {
  final String email;
  final String fullName;
  final bool isVerified;
  final String profilePic;
  final int phoneNum;
  final List<String> cart;
  final List<String> order;
  final List<String> recommendations;
  final List<String> wishlist;

  final String? gender;
  final DateTime? birthdate;

  ProfileModel({
    required this.email,
    required this.fullName,
    required this.isVerified,
    required this.profilePic,
    required this.phoneNum,
    required this.cart,
    required this.order,
    required this.recommendations,
    required this.wishlist,
    this.gender,
    this.birthdate,
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

    DateTime? parseBirthdate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return ProfileModel(
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      isVerified: json['isVerified'] ?? false,
      profilePic: json['profilePic'] ?? '',
      phoneNum: parsePhoneNum(json['phoneNum']),
      cart: List<String>.from(json['cart'] ?? []),
      order: List<String>.from(json['order'] ?? []),
      recommendations: List<String>.from(json['recommendations'] ?? []),
      wishlist: List<String>.from(json['wishlist'] ?? []),
      gender: json['gender'],
        birthdate: parseBirthdate(json['birthdate'])
    );
  }

  // Convert ProfileModel to JSON object
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullName': fullName,
      'isVerified': isVerified,
      'profilePic': profilePic,
      'phoneNum': phoneNum, // Always stored as int
      'cart': cart,
      'order': order,
      'recommendations': recommendations,
      'wishlist': wishlist,
      if (gender != null) 'gender': gender,
      if (birthdate != null) 'birthdate': birthdate!.toIso8601String(),
    };
  }

  // Utility method to create a copy with updated fields
  ProfileModel copyWith({
    String? email,
    String? fullName,
    bool? isVerified,
    String? profilePic,
    int? phoneNum,
    List<String>? cart,
    List<String>? order,
    List<String>? recommendations,
    List<String>? wishlist,
    String? gender,
    DateTime? birthdate,
  }) {
    return ProfileModel(
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      isVerified: isVerified ?? this.isVerified,
      profilePic: profilePic ?? this.profilePic,
      phoneNum: phoneNum ?? this.phoneNum,
      cart: cart ?? this.cart,
      order: order ?? this.order,
      recommendations: recommendations ?? this.recommendations,
      wishlist: wishlist ?? this.wishlist,
      gender: gender ?? this.gender,
      birthdate: birthdate ?? this.birthdate,
    );
  }
}