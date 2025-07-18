import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../model/payment_cards_model.dart';
import '../settings/add_card_view.dart'; // Adjust path if needed

class PaymentMethodSheet extends StatefulWidget {
  final Function(PaymentCard) onPaymentMethodSelected;
  final String userId;

  const PaymentMethodSheet({super.key, required this.onPaymentMethodSelected, required this.userId});

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
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddCardView(userId: widget.userId),
                  ),
                );

                if (mounted) {
                  setState(() {
                    // Refresh the address list
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E6CEF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Add Card',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: 10)
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
        title: Row(
          children: [
            Text(card.displayName),
            const SizedBox(width: 12),
            if (card.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF8E6CEF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Default',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(card.displayName),
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
        color: const Color(0xFF2663D4),
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
