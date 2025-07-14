import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secondsight/view/widgets/custom_back_button.dart';
import '../../controller/settings/cards_list_controller.dart';
import '../../model/payment_cards_model.dart';
import 'add_card_view.dart';


class CardListView extends StatelessWidget {
  final String userId;
  final CardListController controller;

  CardListView({super.key, required this.userId})
      : controller = CardListController(userId: userId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text(
          "Payment Cards",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFFFAFAFA),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: controller.getPaymentCards(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading payment cards',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}', // 👈 shows actual error
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ),
            );
          }


          final cardDocs = snapshot.data?.docs ?? [];

          if (cardDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E6CEF).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.credit_card_outlined,
                      size: 48,
                      color: const Color(0xFF8E6CEF).withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No payment cards yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first payment card',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddCardView(userId: userId),
                        ),
                      );
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
                ],
              ),
            );
          }

          // Convert documents to PaymentCard objects
          final cards = cardDocs.map((doc) => PaymentCard.fromDocument(doc)).toList();

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: card.isDefault
                            ? Border.all(
                          color: const Color(0xFF8E6CEF).withOpacity(0.3),
                          width: 2,
                        )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Card brand icon
                                _buildCardBrandIcon(card.brand),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            card.cardHolderName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          if (card.isDefault) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF8E6CEF),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Default',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _formatCardNumber(card.cardNumber),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                          letterSpacing: 0.5,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: Colors.grey[600],
                                    size: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                  onSelected: (value) {
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                            color: Colors.black87,
                                          ),
                                          SizedBox(width: 12),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    if (!card.isDefault)
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Expires ${card.expiryDate}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    card.brand.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddCardView(userId: userId),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E6CEF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    'Add New Card',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCardBrandIcon(String brand) {
    IconData iconData;
    Color iconColor;

    switch (brand.toLowerCase()) {
      case 'visa':
        iconData = Icons.credit_card;
        iconColor = const Color(0xFF1A1F71);
        break;
      case 'mastercard':
        iconData = Icons.credit_card;
        iconColor = const Color(0xFFEB001B);
        break;
      case 'amex':
      case 'american express':
        iconData = Icons.credit_card;
        iconColor = const Color(0xFF006FCF);
        break;
      case 'discover':
        iconData = Icons.credit_card;
        iconColor = const Color(0xFFFF6000);
        break;
      default:
        iconData = Icons.credit_card_outlined;
        iconColor = Colors.grey[600]!;
    }

    return Container(
      width: 48,
      height: 36,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  String _formatCardNumber(String cardNumber) {
    // Show only last 4 digits
    if (cardNumber.length >= 4) {
      final lastFour = cardNumber.substring(cardNumber.length - 4);
      return '•••• •••• •••• $lastFour';
    }
    return '•••• •••• •••• ••••';
  }
}