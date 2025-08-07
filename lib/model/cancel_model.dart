// ===== ENHANCED CANCELLATION MODEL =====
// cancellation_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum CancellationType {
  order('order'),
  returnRequest('return_request');

  const CancellationType(this.value);
  final String value;
}

class CancellationModel {
  final String id;
  final String referenceID; // Can be orderID or returnRequestID
  final CancellationType cancellationType;
  final String cancelReason;
  final DateTime cancelDate;
  final String? cancelNote;
  final String cancelledBy;

  CancellationModel({
    required this.id,
    required this.referenceID,
    required this.cancellationType,
    required this.cancelReason,
    required this.cancelDate,
    this.cancelNote,
    required this.cancelledBy,
  });

  // Convenience getters for backward compatibility
  String? get orderID => cancellationType == CancellationType.order ? referenceID : null;
  String? get returnRequestID => cancellationType == CancellationType.returnRequest ? referenceID : null;

  // Factory constructor to create from Firestore document
  factory CancellationModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle backward compatibility - if cancellationType doesn't exist, assume it's an order
    final cancellationTypeStr = data['cancellationType'] ?? 'order';
    final cancellationType = CancellationType.values.firstWhere(
          (e) => e.value == cancellationTypeStr,
      orElse: () => CancellationType.order,
    );

    // Handle backward compatibility for referenceID
    String referenceID;
    if (data.containsKey('referenceID')) {
      referenceID = data['referenceID'] ?? '';
    } else {
      // Fallback to legacy field names
      referenceID = data['orderID'] ?? data['returnRequestID'] ?? '';
    }

    return CancellationModel(
      id: doc.id,
      referenceID: referenceID,
      cancellationType: cancellationType,
      cancelReason: data['cancelReason'] ?? '',
      cancelDate: (data['cancelDate'] as Timestamp).toDate(),
      cancelNote: data['cancelNote'],
      cancelledBy: data['cancelledBy'] ?? '',
    );
  }

  // Factory constructor to create from Map
  factory CancellationModel.fromMap(Map<String, dynamic> data, String id) {
    final cancellationTypeStr = data['cancellationType'] ?? 'order';
    final cancellationType = CancellationType.values.firstWhere(
          (e) => e.value == cancellationTypeStr,
      orElse: () => CancellationType.order,
    );

    String referenceID;
    if (data.containsKey('referenceID')) {
      referenceID = data['referenceID'] ?? '';
    } else {
      referenceID = data['orderID'] ?? data['returnRequestID'] ?? '';
    }

    return CancellationModel(
      id: id,
      referenceID: referenceID,
      cancellationType: cancellationType,
      cancelReason: data['cancelReason'] ?? '',
      cancelDate: (data['cancelDate'] as Timestamp).toDate(),
      cancelNote: data['cancelNote'],
      cancelledBy: data['cancelledBy'] ?? '',
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'referenceID': referenceID,
      'cancellationType': cancellationType.value,
      'cancelReason': cancelReason,
      'cancelDate': Timestamp.fromDate(cancelDate),
      'cancelNote': cancelNote,
      'cancelledBy': cancelledBy,
      // Include legacy fields for backward compatibility
      if (cancellationType == CancellationType.order) 'orderID': referenceID,
      if (cancellationType == CancellationType.returnRequest) 'returnRequestID': referenceID,
    };
  }

  // Named constructors for convenience
  factory CancellationModel.forOrder({
    required String id,
    required String orderID,
    required String cancelReason,
    required DateTime cancelDate,
    String? cancelNote,
    required String cancelledBy,
  }) {
    return CancellationModel(
      id: id,
      referenceID: orderID,
      cancellationType: CancellationType.order,
      cancelReason: cancelReason,
      cancelDate: cancelDate,
      cancelNote: cancelNote,
      cancelledBy: cancelledBy,
    );
  }

  factory CancellationModel.forReturnRequest({
    required String id,
    required String returnRequestID,
    required String cancelReason,
    required DateTime cancelDate,
    String? cancelNote,
    required String cancelledBy,
  }) {
    return CancellationModel(
      id: id,
      referenceID: returnRequestID,
      cancellationType: CancellationType.returnRequest,
      cancelReason: cancelReason,
      cancelDate: cancelDate,
      cancelNote: cancelNote,
      cancelledBy: cancelledBy,
    );
  }

  // CopyWith method for immutability
  CancellationModel copyWith({
    String? id,
    String? referenceID,
    CancellationType? cancellationType,
    String? cancelReason,
    DateTime? cancelDate,
    String? cancelNote,
    String? cancelledBy,
  }) {
    return CancellationModel(
      id: id ?? this.id,
      referenceID: referenceID ?? this.referenceID,
      cancellationType: cancellationType ?? this.cancellationType,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelDate: cancelDate ?? this.cancelDate,
      cancelNote: cancelNote ?? this.cancelNote,
      cancelledBy: cancelledBy ?? this.cancelledBy,
    );
  }

  // Helper methods
  bool get isOrderCancellation => cancellationType == CancellationType.order;
  bool get isReturnRequestCancellation => cancellationType == CancellationType.returnRequest;

  String get displayType {
    switch (cancellationType) {
      case CancellationType.order:
        return 'Order Cancellation';
      case CancellationType.returnRequest:
        return 'Return Request Cancellation';
    }
  }
}