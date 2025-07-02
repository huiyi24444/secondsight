// FILE: model/customer_model.dart

class CustomerModel {
  final String id; // Firestore document ID
  final String email;
  final String fullName;
  final bool isVerified;
  final int phoneNum;
  final String profilePic;
  final String status;

  CustomerModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isVerified,
    required this.phoneNum,
    required this.profilePic,
    required this.status,
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
    };
  }
}
