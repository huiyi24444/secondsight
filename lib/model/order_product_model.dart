
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderProductModel {
  final bool eligibilityForReturn;
  final double price;
  final DocumentReference productID;
  final int productQuantity;
  final double totalPrice;

  OrderProductModel({
    required this.eligibilityForReturn,
    required this.price,
    required this.productID,
    required this.productQuantity,
    required this.totalPrice,
  });

  factory OrderProductModel.fromJson(Map<String, dynamic> json) {
    return OrderProductModel(
      eligibilityForReturn: json['eligibilityForReturn'] ?? false,
      price: (json['price'] ?? 0).toDouble(),
      productID: json['productID'] as DocumentReference,
      productQuantity: json['productQuantity'] ?? 1,
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eligibilityForReturn': eligibilityForReturn,
      'price': price,
      'productID': productID,
      'productQuantity': productQuantity,
      'totalPrice': totalPrice,
    };
  }
}