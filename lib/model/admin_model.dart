import 'package:cloud_firestore/cloud_firestore.dart';

class AdminModel {
  final String id; // Document ID
  final String email;
  final bool isAdmin;
  final bool isVerified;
  final bool isEnabled;
  final String name;
  final String role;
  final String? phone;
  final String? department;
  final List<String> permissions;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final DateTime? lastLogout;
  final DateTime? verifiedAt;

  AdminModel({
    required this.id,
    required this.email,
    required this.isAdmin,
    required this.isVerified,
    required this.isEnabled,
    required this.name,
    required this.role,
    this.phone,
    this.department,
    required this.permissions,
    required this.createdAt,
    this.lastLogin,
    this.lastLogout,
    this.verifiedAt,
  });

  factory AdminModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AdminModel(
      id: doc.id,
      email: data['email'] ?? '',
      isAdmin: data['isAdmin'] ?? false,
      isVerified: data['isVerified'] ?? false,
      isEnabled: data['isEnabled'] ?? false,
      name: data['name'] ?? '',
      role: data['role'] ?? '',
      phone: data['phone'] ?? '',
      department: data['department'] ?? '',
      permissions: List<String>.from(data['permissions'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLogin: data['lastLogin'] != null ? (data['lastLogin'] as Timestamp).toDate() : null,
      lastLogout: data['lastLogout'] != null ? (data['lastLogout'] as Timestamp).toDate() : null,
      verifiedAt: data['verifiedAt'] != null ? (data['verifiedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'isAdmin': isAdmin,
      'isVerified': isVerified,
      'isEnabled': isEnabled,
      'name': name,
      'role': role,
      'phone': phone,
      'department': department,
      'permissions': permissions,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'lastLogout': lastLogout != null ? Timestamp.fromDate(lastLogout!) : null,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
    };
  }
}
