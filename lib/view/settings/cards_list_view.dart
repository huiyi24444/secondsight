// cards_list_view.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secondsight/view/widgets/custom_back_button.dart';
import '../../controller/settings/cards_list_controller.dart';
import '../../model/payment_cards_model.dart';
import '../../services/stripe_service.dart';
import '../widgets/format_card.dart'; // Import your StripeService

class CardListView extends StatefulWidget {
  final String userId;

  const CardListView({super.key, required this.userId});

  @override
  State<CardListView> createState() => _CardListViewState();
}

class _CardListViewState extends State<CardListView> {
  late final CardListController controller;
  bool isAddingCard = false;

  @override
  void initState() {
    super.initState();
    controller = CardListController(userId: widget.userId);
  }

  // Add payment method using Stripe Setup Intent
  Future<void> _addPaymentMethod() async {
    setState(() {
      isAddingCard = true;
    });

    try {
      // Get or create Stripe customer
      final customerId = await _getOrCreateStripeCustomer();

      // Use StripeService to save payment method
      final result = await StripeService.savePaymentMethod(
        userId: widget.userId,
        customerId: customerId,
      );

      if (result.success && result.paymentMethodDetails != null) {
        // Save payment method reference to Firestore
        await _savePaymentMethodToFirestore(result.paymentMethodDetails!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment method added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted && result.message.toLowerCase() != 'setup cancelled') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isAddingCard = false;
        });
      }
    }
  }

  // Get or create Stripe customer
  Future<String> _getOrCreateStripeCustomer() async {
    try {
      // Check if user already has a Stripe customer ID
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists && userDoc.data()?['stripeCustomerId'] != null) {
        return userDoc.data()!['stripeCustomerId'];
      }

      // Create new Stripe customer using StripeService
      final customerId = await StripeService.createCustomer(
        userId: widget.userId,
        email: userDoc.data()?['email'] ?? '',
        name: userDoc.data()?['name'] ?? '',
      );

      // Save customer ID to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'stripeCustomerId': customerId});

      return customerId;
    } catch (e) {
      throw Exception('Error with Stripe customer: $e');
    }
  }

  // Save payment method reference to Firestore
  Future<void> _savePaymentMethodToFirestore(Map<String, dynamic> paymentMethodData) async {
    try {
      // Check if this should be the first/default card
      final existingCards = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('paymentMethods')
          .get();

      final isFirstCard = existingCards.docs.isEmpty;

      if (isFirstCard) {
        // If this is the first card, make it default
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('paymentMethods')
            .add({
          'stripePaymentMethodId': paymentMethodData['id'],
          'lastFour': paymentMethodData['card']['last4'],
          'brand': paymentMethodData['card']['brand'],
          'expMonth': paymentMethodData['card']['exp_month'],
          'expYear': paymentMethodData['card']['exp_year'],
          'isDefault': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Just add the payment method as non-default
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('paymentMethods')
            .add({
          'stripePaymentMethodId': paymentMethodData['id'],
          'lastFour': paymentMethodData['card']['last4'],
          'brand': paymentMethodData['card']['brand'],
          'expMonth': paymentMethodData['card']['exp_month'],
          'expYear': paymentMethodData['card']['exp_year'],
          'isDefault': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving payment method to Firestore: $e');
      rethrow;
    }
  }

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
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
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
                    'Add your first payment card securely with Stripe',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),


                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: isAddingCard ? null : _addPaymentMethod,
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
                    icon: isAddingCard
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.add, size: 20),
                    label: Text(
                      isAddingCard ? 'Processing...' : 'Add Card',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

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
                                        formatCardNumber(card.lastFour),
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
                                    // Handle menu actions
                                  },
                                  itemBuilder: (context) => [
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
                                        'Expires ${card.expMonth.toString().padLeft(2, '0')}/${card.expYear}',
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
                  onPressed: isAddingCard ? null : _addPaymentMethod,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E6CEF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: isAddingCard
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.add, size: 20),
                  label: Text(
                    isAddingCard ? 'Processing...' : 'Add New Card',
                    style: const TextStyle(
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
}