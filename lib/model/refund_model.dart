
// model/refund_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RefundModel {
  final String id;
  final String returnRequestId;
  final double refundAmount;
  final String refundMethod;
  final DateTime refundDate;
  final String transactionId;


  RefundModel({
    required this.id,
    required this.returnRequestId,
    required this.refundAmount,
    required this.refundMethod,
    required this.refundDate,
    required this.transactionId,
  });

  factory RefundModel.fromJson(Map<String, dynamic> json) {
    return RefundModel(
      id: json['id'] ?? '',
      returnRequestId: json['returnRequestId'] ?? '',
      refundAmount: (json['refundAmount'] ?? 0).toDouble(),
      refundMethod: json['refundMethod'] ?? '',
      refundDate: (json['refundDate'] as Timestamp).toDate(),
      transactionId: json['transactionId'] ?? '',
    );
  }

  factory RefundModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RefundModel.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'returnRequestId': returnRequestId,
      'refundAmount': refundAmount,
      'refundMethod': refundMethod,
      'refundDate': Timestamp.fromDate(refundDate),
      'transactionId': transactionId,
    };
  }

  RefundModel copyWith({
    String? id,
    String? returnRequestId,
    double? refundAmount,
    String? refundMethod,
    DateTime? refundDate,
    String? transactionId,

  }) {
    return RefundModel(
      id: id ?? this.id,
      returnRequestId: returnRequestId ?? this.returnRequestId,
      refundAmount: refundAmount ?? this.refundAmount,
      refundMethod: refundMethod ?? this.refundMethod,
      refundDate: refundDate ?? this.refundDate,
      transactionId: transactionId ?? this.transactionId,
    );
  }
}