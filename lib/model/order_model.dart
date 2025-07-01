import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersModel {
  final String id;
  final String? customerId;
  final DateTime orderDate;
  final String orderStatus;
  final double totalAmount;
  final bool eligibilityForReturn;
  final String? shipmentID; // link to shipment subdoc
  final String payment;

  OrdersModel({
    required this.id,
    this.customerId,
    required this.orderDate,
    required this.orderStatus,
    required this.totalAmount,
    required this.eligibilityForReturn,
    this.shipmentID,
    this.payment = "Mastercard",

  });

  factory OrdersModel.fromJson(Map<String, dynamic> json, String docId) {
    return OrdersModel(
      id: docId,
      customerId: json['customerId'], // optional, might be null
      orderDate: (json['orderDate'] as Timestamp).toDate(),
      orderStatus: json['orderStatus'] ?? 'processing',
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      eligibilityForReturn: json['eligibilityForReturn'] ?? false,
      shipmentID: json['shipmentID'],
      payment: json['payment'] ?? 'Mastercard',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'orderDate': Timestamp.fromDate(orderDate),
      'orderStatus': orderStatus,
      'totalAmount': totalAmount,
      'eligibilityForReturn': eligibilityForReturn,
      'shipmentID': shipmentID,
      'payment': payment,
    };
  }

  OrdersModel copyWith({
    String? id,
    String? customerId,
    DateTime? orderDate,
    String? orderStatus,
    double? totalAmount,
    bool? eligibilityForReturn,
    String? shipmentID,
    String? payment,
  }) {
    return OrdersModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      orderDate: orderDate ?? this.orderDate,
      orderStatus: orderStatus ?? this.orderStatus,
      totalAmount: totalAmount ?? this.totalAmount,
      eligibilityForReturn: eligibilityForReturn ?? this.eligibilityForReturn,
      shipmentID: shipmentID ?? this.shipmentID,
      payment: payment ?? this.payment,
    );
  }

  String get shortOrderId =>
      (id.length >= 6 ? id.substring(0, 6) : id).toUpperCase();
}
