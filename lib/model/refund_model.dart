
// model/refund_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RefundModel {
  final String id;
  final String orderId;
  final String? returnRequestId;
  final String? cancelId;
  final double refundAmount;
  final String refundMethod;
  final DateTime refundDate;
  final String transactionId;
  final String customerId;
  final String refundType;



  RefundModel({
    required this.id,
    required this.orderId,
    this.returnRequestId,
    this.cancelId,
    required this.refundAmount,
    required this.refundMethod,
    required this.refundDate,
    required this.transactionId,
    required this.customerId,
    required this.refundType,
  });

  factory RefundModel.fromJson(Map<String, dynamic> json) {
    return RefundModel(
      id: json['id'] ?? '',
      orderId: json['orderId'] ?? '',
      returnRequestId: json['returnRequestId'],
      cancelId: json['cancelId'],
      refundAmount: (json['refundAmount'] ?? 0).toDouble(),
      refundMethod: json['refundMethod'] ?? '',
      refundDate: (json['refundDate'] as Timestamp).toDate(),
      transactionId: json['transactionId'] ?? '',
      customerId: json['customerId'] ?? '',
      refundType: json['refundType'] ?? 'return',
    );
  }

  factory RefundModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RefundModel.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'returnRequestId': returnRequestId,
      'cancelId': cancelId,
      'refundAmount': refundAmount,
      'refundMethod': refundMethod,
      'refundDate': Timestamp.fromDate(refundDate),
      'transactionId': transactionId,
      'customerId': customerId,
      'refundType': refundType,
    };
  }

  RefundModel copyWith({
    String? id,
    String? orderId,
    String? returnRequestId,
    String? cancelId,
    double? refundAmount,
    String? refundMethod,
    DateTime? refundDate,
    String? transactionId,
    String? customerId,
    String? refundType,
  }) {
    return RefundModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      returnRequestId: returnRequestId ?? this.returnRequestId,
      cancelId: cancelId ?? this.cancelId,
      refundAmount: refundAmount ?? this.refundAmount,
      refundMethod: refundMethod ?? this.refundMethod,
      refundDate: refundDate ?? this.refundDate,
      transactionId: transactionId ?? this.transactionId,
      customerId: customerId ?? this.customerId,
      refundType: refundType ?? this.refundType,
    );
  }
}