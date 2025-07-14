import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../model/payment_cards_model.dart'; // Adjust path if needed

class PaymentMethodSheet extends StatefulWidget {
  final Function(PaymentCard) onPaymentMethodSelected;

  const PaymentMethodSheet({super.key, required this.onPaymentMethodSelected});

  @override
  State<PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<PaymentMethodSheet> {
  List<PaymentCard> paymentCards = [];
  String? selectedCardId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPaymentCards();
  }

  Future<void> _fetchPaymentCards() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('paymentCards')
          .get();

      final fetched = snapshot.docs.map((doc) => PaymentCard.fromDocument(doc)).toList();

      setState(() {
        paymentCards = fetched;
        final defaultCard = fetched.where((card) => card.isDefault).toList();
        selectedCardId = defaultCard.isNotEmpty
            ? defaultCard.first.id
            : (fetched.isNotEmpty ? fetched.first.id : null);
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching cards: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : paymentCards.isEmpty
                ? const Center(child: Text('No payment methods found.'))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: paymentCards.length,
              itemBuilder: (context, index) {
                final card = paymentCards[index];
                return _buildPaymentOption(
                  card: card,
                  isSelected: selectedCardId == card.id,
                  onTap: () {
                    setState(() {
                      selectedCardId = card.id;
                    });
                    widget.onPaymentMethodSelected(card); // Pass the whole card
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required PaymentCard card,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: _buildCardBrandBadge(card.brand),
        title: Text(card.cardNumber),
        subtitle: Text(card.cardHolderName),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Color(0xFF8B5CF6))
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildCardBrandBadge(String brand) {
    return Container(
      width: 50,
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          brand.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
