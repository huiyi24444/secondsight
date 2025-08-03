import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLogModel {
  final String id; // Log document ID
  final String action;
  final DateTime timestamp;
  final Map<String, dynamic>? details;
  final String? adminId; // Optional if used in global logs

  AdminLogModel({
    required this.id,
    required this.action,
    required this.timestamp,
    this.details,
    this.adminId,
  });

  factory AdminLogModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AdminLogModel(
      id: doc.id,
      action: data['action'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      details: data['details'] != null ? Map<String, dynamic>.from(data['details']) : null,
      adminId: data['adminId'], // Only needed if used in global logs
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'timestamp': Timestamp.fromDate(timestamp),
      if (details != null) 'details': details,
      if (adminId != null) 'adminId': adminId,
    };
  }
}
