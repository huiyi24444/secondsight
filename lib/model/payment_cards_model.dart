import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentCard {
  final String id;
  final String brand;
  final Timestamp createdAt;
  final String displayName;
  final int expMonth;
  final int expYear;
  final bool isDefault;
  final String lastFour;
  final String stripePaymentMethodId;

  PaymentCard({
    required this.id,
    required this.brand,
    required this.createdAt,
    required this.displayName,
    required this.expMonth,
    required this.expYear,
    required this.isDefault,
    required this.lastFour,
    required this.stripePaymentMethodId,
  });

  factory PaymentCard.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentCard(
      id: doc.id,
      brand: data['brand'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      displayName: data['displayName'] ?? '',
      expMonth: data['expMonth'] ?? 1,
      expYear: data['expYear'] ?? DateTime.now().year,
      isDefault: data['isDefault'] ?? false,
      lastFour: data['lastFour'] ?? '',
      stripePaymentMethodId: data['stripePaymentMethodId'] ?? '',
    );
  }
}
