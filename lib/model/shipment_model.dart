import 'package:cloud_firestore/cloud_firestore.dart';


class ShipmentModel {
  final String id;
  final String shipAddress;
  final DateTime shippedDate;
  final String trackingNumber;

  ShipmentModel({
    required this.id,
    required this.shipAddress,
    required this.shippedDate,
    required this.trackingNumber,
  });

  factory ShipmentModel.fromJson(Map<String, dynamic> json, String docId) {
    return ShipmentModel(
      id: docId,
      shipAddress: json['shipAddress'],
      shippedDate: (json['shippedDate'] as Timestamp).toDate(),
      trackingNumber: json['trackingNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shipAddress': shipAddress,
      'shippedDate': Timestamp.fromDate(shippedDate),
      'trackingNumber': trackingNumber,
    };
  }
}
