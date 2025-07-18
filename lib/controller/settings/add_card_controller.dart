// add_card_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/stripe_service.dart';

class AddCardController extends ChangeNotifier {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State
  bool isDefault = false;
  bool isLoading = false;

  AddCardController({required this.userId});

  void updateDefault(bool? value) {
    isDefault = value ?? false;
    notifyListeners();
  }

  // Save payment method using StripeService
  Future<void> saveCard(BuildContext context) async {
    isLoading = true;
    notifyListeners();

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

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment method added successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } else {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      isLoading = false;
      if (hasListeners) {
        notifyListeners();
      }
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
      // If this is set as default, update other cards
      if (isDefault) {
        final batch = _firestore.batch();

        // Set all existing cards to non-default
        final existingCards = await _firestore
            .collection('users')
            .doc(userId)
            .collection('paymentMethods')
            .get();

        for (var doc in existingCards.docs) {
          batch.update(doc.reference, {'isDefault': false});
        }

        // Add the new payment method
        final newMethodRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('paymentMethods')
            .doc();

        batch.set(newMethodRef, {
          'stripePaymentMethodId': paymentMethodData['id'],
          'lastFour': paymentMethodData['card']['last4'],
          'brand': paymentMethodData['card']['brand'],
          'expMonth': paymentMethodData['card']['exp_month'],
          'expYear': paymentMethodData['card']['exp_year'],
          'isDefault': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();
      } else {
        // Just add the payment method
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('paymentMethods')
            .add({
          'stripePaymentMethodId': paymentMethodData['id'],
          'lastFour': paymentMethodData['card']['last4'],
          'brand': paymentMethodData['card']['brand'],
          'expMonth': paymentMethodData['card']['exp_month'],
          'expYear': paymentMethodData['card']['exp_year'],
          'isDefault': isDefault,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving payment method to Firestore: $e');
      rethrow;
    }
  }
}