import 'package:cloud_firestore/cloud_firestore.dart';


class OrdersModel {
  final String id;
  final DateTime orderDate;
  final String orderStatus;
  final double totalAmount;
  final bool eligibilityForReturn;
  final String? shipmentID; // link to shipment subdoc

  OrdersModel({
    required this.id,
    required this.orderDate,
    required this.orderStatus,
    required this.totalAmount,
    required this.eligibilityForReturn,
    this.shipmentID,
  });

  factory OrdersModel.fromJson(Map<String, dynamic> json, String docId) {
    return OrdersModel(
      id: docId,
      orderDate: (json['orderDate'] as Timestamp).toDate(),
      orderStatus: json['orderStatus'] ?? 'processing',
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      eligibilityForReturn: json['eligibilityForReturn'] ?? false,
      shipmentID: json['shipmentID'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderDate': Timestamp.fromDate(orderDate),
      'orderStatus': orderStatus,
      'totalAmount': totalAmount,
      'eligibilityForReturn': eligibilityForReturn,
      'shipmentID': shipmentID,
    };
  }
  String get shortOrderId =>
      (id.length >= 6 ? id.substring(0, 6) : id).toUpperCase();
}
