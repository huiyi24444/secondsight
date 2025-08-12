import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../model/payment_cards_model.dart';
import '../settings/add_card_view.dart';
import '../widgets/format_card.dart'; // Adjust path if needed

class PaymentCardSheet extends StatefulWidget {
  final Function(PaymentCard) onPaymentCardSelected;
  final String userId;
  final String? currentlySelectedCardId; // Add this parameter

  const PaymentCardSheet({
    super.key,
    required this.onPaymentCardSelected,
    required this.userId,
    this.currentlySelectedCardId, // Add this parameter
  });

  @override
  State<PaymentCardSheet> createState() => _PaymentCardSheetState();
}

class _PaymentCardSheetState extends State<PaymentCardSheet> {
  List<PaymentCard> paymentCards = [];
  String? selectedCardId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    print('PaymentCardSheet opened with currentlySelectedCardId: ${widget.currentlySelectedCardId}');
    _fetchPaymentCards();
  }

  Future<void> _fetchPaymentCards() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('paymentCards')
          .get();

      final fetched = snapshot.docs.map((doc) => PaymentCard.fromDocument(doc)).toList();

      setState(() {
        paymentCards = fetched;

        // Priority order: current selection -> default -> first available
        String? cardToSelect;

        // 1. Try to use the currently selected card if it exists in the list
        if (widget.currentlySelectedCardId != null &&
            fetched.any((card) => card.id == widget.currentlySelectedCardId)) {
          cardToSelect = widget.currentlySelectedCardId;
        }
        // 2. If no current selection or it doesn't exist, try default
        else {
          final defaultCard = fetched.where((card) => card.isDefault).firstOrNull;
          cardToSelect = defaultCard?.id;
        }
        // 3. If no default, use first available
        if (cardToSelect == null && fetched.isNotEmpty) {
          cardToSelect = fetched.first.id;
        }

        selectedCardId = cardToSelect;
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
              'Select Payment Card',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : paymentCards.isEmpty
                ? const Center(child: Text('No payment cards found.'))
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
                    widget.onPaymentCardSelected(card);
                    // Don't close the sheet - let user see the selection change
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddCardView(userId: widget.userId),
                    ),
                  );

                  if (mounted) {
                    await _fetchPaymentCards();
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFF8E6CEF)),
                ),
                icon: const Icon(Icons.add, size: 20, color: Color(0xFF8E6CEF)),
                label: const Text(
                  'Add New Card',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8E6CEF),
                  ),
                ),
              ),
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
        title: Row(
          children: [
            Flexible(
              child: Text(
                formatCardNumber(card.lastFour),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (card.isDefault) ...[
              const SizedBox(width: 8),
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
          ],
        ),
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