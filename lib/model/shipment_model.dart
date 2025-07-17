import 'package:cloud_firestore/cloud_firestore.dart';

class ShipmentModel {
  final String id;
  final DateTime? shippedDate;
  final String? trackingNumber;
  final String shipAddress; // Keep this for backward compatibility
  final String? fullName;
  final int? phoneNum;
  final String? streetone;
  final String? streettwo;
  final String? city;
  final String? state;
  final String? zipCode;

  ShipmentModel({
    required this.id,
    this.shippedDate,
    this.trackingNumber,
    required this.shipAddress,
    this.fullName,
    this.phoneNum,
    this.streetone,
    this.streettwo,
    this.city,
    this.state,
    this.zipCode,
  });

  factory ShipmentModel.fromMap(Map<String, dynamic> map, String id) {
    print("fullName from Firestore: ${map['fullName']}");
    print("phoneNum from Firestore: ${map['phoneNum']} (${map['phoneNum']?.runtimeType})");
    return ShipmentModel(
      id: id,
      shippedDate: map['shippedDate'] != null
          ? (map['shippedDate'] as Timestamp).toDate()
          : null,
      trackingNumber: map['trackingNumber'],
      shipAddress: map['shipAddress'] ?? '',
      fullName: map['fullName'],
      phoneNum: map['phoneNum'],
      streetone: map['streetone'],
      streettwo: map['streettwo'],
      city: map['city'],
      state: map['state'],
      zipCode: map['zipCode'],
    );
  }


  Map<String, dynamic> toMap() {
    return {
      'shippedDate': shippedDate != null ? Timestamp.fromDate(shippedDate!) : null,
      'trackingNumber': trackingNumber,
      'shipAddress': shipAddress,
      'fullName': fullName,
      'phoneNum': phoneNum,
      'streetone': streetone,
      'streettwo': streettwo,
      'city': city,
      'state': state,
      'zipCode': zipCode,
    };
  }
}