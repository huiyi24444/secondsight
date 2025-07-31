// FILE: model/customer_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String id; // Firestore document ID
  final String email;
  final String fullName;
  final bool isVerified;
  final int phoneNum;
  final String profilePic;
  final String status;
  final DateTime createdAt;

  CustomerModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isVerified,
    required this.phoneNum,
    required this.profilePic,
    required this.status,
    required this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json, String docId) {
    return CustomerModel(
      id: docId,
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      isVerified: json['isVerified'] ?? false,
      phoneNum: json['phoneNum'] ?? 0,
      profilePic: json['profilePic'] ?? '',
      status: json['status'] ?? 'active',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullName': fullName,
      'isVerified': isVerified,
      'phoneNum': phoneNum,
      'profilePic': profilePic,
      'status': status,
      'createdAt': createdAt
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'isVerified': isVerified,
      'phoneNum': phoneNum,
      'profilePic': profilePic,
      'status': status,
      'createdAt': createdAt,
    };
  }

}
