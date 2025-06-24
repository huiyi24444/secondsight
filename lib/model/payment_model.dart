import 'card_model.dart';

class PaymentModel {
  List<CardModel> cards;
  String paypalEmail;

  PaymentModel({
    required this.cards,
    required this.paypalEmail,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      cards: (json['cards'] as List<dynamic>)
          .map((card) => CardModel.fromJson(card))
          .toList(),
      paypalEmail: json['paypalEmail'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cards': cards.map((card) => card.toJson()).toList(),
      'paypalEmail': paypalEmail,
    };
  }
}
