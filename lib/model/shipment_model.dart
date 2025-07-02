import 'package:cloud_firestore/cloud_firestore.dart';


class ShipmentModel {
  final String id;
  final String shipAddress;
  final DateTime? shippedDate;
  final String? trackingNumber;

  ShipmentModel({
    required this.id,
    required this.shipAddress,
    this.shippedDate,
    this.trackingNumber,
  });

  factory ShipmentModel.fromJson(Map<String, dynamic> json, String docId) {
    return ShipmentModel(
      id: docId,
      shipAddress: json['shipAddress'],
      shippedDate: (json['shippedDate'] as Timestamp).toDate(),
      trackingNumber: json['trackingNumber'],
    );
  }


  Map<String, dynamic> toMap() {
    return {
      'shipAddress': shipAddress,
      'shippedDate': shippedDate != null ? Timestamp.fromDate(shippedDate!) : null,
      'trackingNumber': trackingNumber,
    };
  }


  factory ShipmentModel.fromMap(Map<String, dynamic> map, String id) {
    return ShipmentModel(
      id: id,
      shipAddress: map['shipAddress'] ?? 'Unknown address',
      shippedDate: map['shippedDate'] != null
          ? (map['shippedDate'] as Timestamp).toDate()
          : null,
      trackingNumber: map['trackingNumber'],
    );
  }
}
