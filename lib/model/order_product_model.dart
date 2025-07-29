
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderProductModel {
  final double price;
  final DocumentReference productID;
  final int productQuantity;
  final double totalPrice;

  OrderProductModel({
    required this.price,
    required this.productID,
    required this.productQuantity,
    required this.totalPrice,
  });

  factory OrderProductModel.fromJson(Map<String, dynamic> json) {
    return OrderProductModel(
      price: (json['price'] ?? 0).toDouble(),
      productID: json['productID'] as DocumentReference,
      productQuantity: json['productQuantity'] ?? 1,
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'price': price,
      'productID': productID,
      'productQuantity': productQuantity,
      'totalPrice': totalPrice,
    };
  }

  factory OrderProductModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return OrderProductModel(
      price: (data['price'] ?? 0).toDouble(),
      productID: data['productID'] as DocumentReference,
      productQuantity: data['productQuantity'] ?? 1,
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
    );
  }
}