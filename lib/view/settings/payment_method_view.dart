// File: payment_method_view.dart
import 'package:flutter/material.dart';
import '../../model/card_model.dart';
import 'add_card_view.dart';

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
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddCardView(
                        onSave: (CardModel newCard) {

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Card ending in ${newCard.cardNumber.substring(newCard.cardNumber.length - 4)} added!")),
                          );

                          // Then pop back to PaymentMethodView
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  );
                },

                child: const Text("Add Card", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),

      ),
    );
  }
}