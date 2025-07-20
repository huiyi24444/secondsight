// cards_list_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/stripe_service.dart';

class CardListController {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CardListController({required this.userId});

  Stream<QuerySnapshot> getPaymentCards() {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('paymentCards')
        .orderBy('isDefault', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('Fetched ${snapshot.docs.length} payment cards:');
      for (var doc in snapshot.docs) {
        debugPrint(doc.data().toString());
      }
      return snapshot;
    });
  }

  // Delete payment card with Stripe integration
  Future<void> deleteCard({
    required BuildContext context,
    required String cardId,
    required String cardNumber,
    required String? stripePaymentMethodId,
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
        // Delete from Stripe first (if we have the payment method ID)
        if (stripePaymentMethodId != null) {
          await StripeService.deletePaymentMethod(stripePaymentMethodId);
        }

        // Then delete from Firestore
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

  // Get all saved payment methods for a user
  Future<List<Map<String, dynamic>>> getSavedPaymentMethods() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('paymentCards')
          .orderBy('isDefault', descending: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add document ID
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Error getting saved payment methods: $e');
    }
  }

  // Check if user has any saved payment methods
  Future<bool> hasPaymentMethods() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('paymentCards')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get default payment method
  Future<Map<String, dynamic>?> getDefaultPaymentCards() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('paymentCards')
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        data['id'] = snapshot.docs.first.id;
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}