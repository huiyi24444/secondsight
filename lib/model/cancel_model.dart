
// ===== CANCELLATION MODEL =====
// cancellation_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CancellationModel {
  final String id;
  final String orderID;
  final String cancelReason;
  final DateTime cancelDate;
  final String? cancelNote;
  final String canceledBy;

  CancellationModel({
    required this.id,
    required this.orderID,
    required this.cancelReason,
    required this.cancelDate,
    this.cancelNote,
    required this.canceledBy,
  });

  // Factory constructor to create from Firestore document
  factory CancellationModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CancellationModel(
      id: doc.id,
      orderID: data['orderID'] ?? '',
      cancelReason: data['cancelReason'] ?? '',
      cancelDate: (data['cancelDate'] as Timestamp).toDate(),
      cancelNote: data['cancelNote'],
      canceledBy: data['canceledBy'] ?? '',
    );
  }

  // Factory constructor to create from Map
  factory CancellationModel.fromMap(Map<String, dynamic> data, String id) {
    return CancellationModel(
      id: id,
      orderID: data['orderID'] ?? '',
      cancelReason: data['cancelReason'] ?? '',
      cancelDate: (data['cancelDate'] as Timestamp).toDate(),
      cancelNote: data['cancelNote'],
      canceledBy: data['canceledBy'] ?? '',
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'orderID': orderID,
      'cancelReason': cancelReason,
      'cancelDate': Timestamp.fromDate(cancelDate),
      'cancelNote': cancelNote,
      'canceledBy': canceledBy,
    };
  }

  // CopyWith method for immutability
  CancellationModel copyWith({
    String? id,
    String? orderID,
    String? cancelReason,
    DateTime? cancelDate,
    String? cancelNote,
    String? canceledBy,
  }) {
    return CancellationModel(
      id: id ?? this.id,
      orderID: orderID ?? this.orderID,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelDate: cancelDate ?? this.cancelDate,
      cancelNote: cancelNote ?? this.cancelNote,
      canceledBy: canceledBy ?? this.canceledBy,
    );
  }
}