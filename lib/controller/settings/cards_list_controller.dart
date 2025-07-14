import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CardListController {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CardListController({required this.userId});

  // Get payment cards stream
  Stream<QuerySnapshot> getPaymentCards() {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('paymentCards')
        .orderBy('isDefault', descending: true)
        .orderBy('cardHolderName')
        .snapshots();
  }

  // Delete payment card
  Future<void> deleteCard({
    required BuildContext context,
    required String cardId,
    required String cardNumber,
  }) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text('Are you sure you want to delete the card ending in ${cardNumber.split(' ').last}?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('paymentCards')
            .doc(cardId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Card deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting card: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Set default payment card
  Future<void> setDefaultCard(String cardId) async {
    try {
      // First, remove default status from all cards
      final batch = _firestore.batch();

      final cardsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('paymentCards')
          .get();

      for (var doc in cardsSnapshot.docs) {
        batch.update(doc.reference, {'isDefault': false});
      }

      // Then set the selected card as default
      batch.update(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('paymentCards')
            .doc(cardId),
        {'isDefault': true},
      );

      await batch.commit();
    } catch (e) {
      throw Exception('Error setting default card: $e');
    }
  }
}