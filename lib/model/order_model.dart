// orders_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersModel {
  final String id;
  final DateTime orderDate;
  final String orderStatus;
  final double totalAmount;
  final String? shippingAddress;
  final String? paymentMethod;
  final String? trackingNumber;

  OrdersModel({
    required this.id,
    required this.orderDate,
    required this.orderStatus,
    required this.totalAmount,
    this.shippingAddress,
    this.paymentMethod,
    this.trackingNumber,
  });

  factory OrdersModel.fromJson(Map<String, dynamic> json, String docId) {
    return OrdersModel(
      id: docId,
      orderDate: (json['orderDate'] as Timestamp).toDate(),
      orderStatus: json['orderStatus'] ?? 'processing',
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      shippingAddress: json['shippingAddress'],
      paymentMethod: json['paymentMethod'],
      trackingNumber: json['trackingNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderDate': Timestamp.fromDate(orderDate),
      'orderStatus': orderStatus,
      'totalAmount': totalAmount,
      'shippingAddress': shippingAddress,
      'paymentMethod': paymentMethod,
      'trackingNumber': trackingNumber,
    };
  }
}
