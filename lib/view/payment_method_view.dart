// File: payment_method_view.dart
import 'package:flutter/material.dart';
import '../model/card_model.dart';

class PaymentMethodView extends StatelessWidget {
  final List<CardModel> cards;
  final String paypalEmail;

  const PaymentMethodView({super.key, required this.cards, required this.paypalEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment"),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Cards", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...cards.map((card) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("**** ${card.cardNumber.substring(card.cardNumber.length - 4)}"),
                  const Icon(Icons.chevron_right)
                ],
              ),
            )),
            const SizedBox(height: 20),
            const Text("Paypal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(paypalEmail),
                  const Icon(Icons.chevron_right)
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}