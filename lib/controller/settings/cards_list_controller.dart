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

  // Add payment method using Stripe Setup Intent
  Future<Map<String, dynamic>> addPaymentMethod() async {
    try {
      // Get or create Stripe customer
      final customerId = await _getOrCreateStripeCustomer();

      // Use StripeService to save payment method
      final result = await StripeService.savePaymentMethod(
        userId: userId,
        customerId: customerId,
      );

      if (result.success && result.paymentMethodDetails != null) {
        // Save payment method reference to Firestore
        await _savePaymentMethodToFirestore(result.paymentMethodDetails!);
        return {
          'success': true,
          'message': 'Payment method added successfully'
        };
      } else {
        return {
          'success': false,
          'message': result.message
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}'
      };
    }
  }

  // Get or create Stripe customer
  Future<String> _getOrCreateStripeCustomer() async {
    try {
      // Check if user already has a Stripe customer ID
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists && userDoc.data()?['stripeCustomerId'] != null) {
        return userDoc.data()!['stripeCustomerId'];
      }

      // Create new Stripe customer using StripeService
      final customerId = await StripeService.createCustomer(
        userId: userId,
        email: userDoc.data()?['email'] ?? '',
        name: userDoc.data()?['name'] ?? '',
      );

      // Save customer ID to Firestore
      await _firestore
          .collection('users')
          .doc(userId)
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
      final existingCards = await _firestore
          .collection('users')
          .doc(userId)
          .collection('paymentCards')
          .get();

      final isFirstCard = existingCards.docs.isEmpty;

      if (isFirstCard) {
        // If this is the first card, make it default
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('paymentCards')
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
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('paymentCards')
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

  // Set card as default
  Future<void> setCardAsDefault(String cardId) async {
    try {
      // Start a batch to ensure atomicity
      final batch = _firestore.batch();

      // First, set all cards to non-default
      final cardsQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('paymentCards')
          .get();

      for (final doc in cardsQuery.docs) {
        batch.update(doc.reference, {'isDefault': false});
      }

      // Then set the selected card as default
      batch.update(
          _firestore
              .collection('users')
              .doc(userId)
              .collection('paymentCards')
              .doc(cardId),
          {'isDefault': true}
      );

      // Commit the batch
      await batch.commit();
    } catch (e) {
      throw Exception('Error setting default card: $e');
    }
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

  // Alternative delete method without UI context (for use in view)
  Future<void> deleteCardById(String cardId, String? stripePaymentMethodId) async {
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
    } catch (e) {
      throw Exception('Error deleting card: $e');
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