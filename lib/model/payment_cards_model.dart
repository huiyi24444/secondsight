import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentCard {
  final String id;
  final String cardNumber;
  final String cardHolderName;
  final String expiryDate;
  final String brand;
  final bool isDefault;

  PaymentCard({
    required this.id,
    required this.cardNumber,
    required this.cardHolderName,
    required this.expiryDate,
    required this.brand,
    required this.isDefault,
  });

  factory PaymentCard.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentCard(
      id: doc.id,
      cardNumber: data['cardNumber'] ?? '',
      cardHolderName: data['cardHolderName'] ?? '',
      expiryDate: data['expiryDate'] ?? '',
      brand: data['brand'] ?? '',
      isDefault: data['isDefault'] ?? false,
    );
  }
}
