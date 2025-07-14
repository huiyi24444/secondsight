import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddCardController extends ChangeNotifier {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController cardNumberController = TextEditingController();
  final TextEditingController cardHolderNameController = TextEditingController();
  final TextEditingController expiryDateController = TextEditingController();
  final TextEditingController cvvController = TextEditingController();

  // State
  bool isDefault = false;
  bool isLoading = false;
  String detectedBrand = '';

  AddCardController({required this.userId});

  @override
  void dispose() {
    cardNumberController.dispose();
    cardHolderNameController.dispose();
    expiryDateController.dispose();
    cvvController.dispose();
    super.dispose();
  }

  void updateDefault(bool? value) {
    isDefault = value ?? false;
    notifyListeners();
  }

  void onCardNumberChanged(String value) {
    // Remove spaces for validation
    final cleanNumber = value.replaceAll(' ', '');

    // Detect card brand based on first digits
    if (cleanNumber.isNotEmpty) {
      if (cleanNumber.startsWith('4')) {
        detectedBrand = 'visa';
      } else if (cleanNumber.startsWith('5') && cleanNumber.length >= 2) {
        final firstTwo = int.tryParse(cleanNumber.substring(0, 2)) ?? 0;
        if (firstTwo >= 51 && firstTwo <= 55) {
          detectedBrand = 'mastercard';
        }
      } else if (cleanNumber.startsWith('3')) {
        if (cleanNumber.length >= 2) {
          final firstTwo = cleanNumber.substring(0, 2);
          if (firstTwo == '34' || firstTwo == '37') {
            detectedBrand = 'amex';
          }
        }
      } else if (cleanNumber.startsWith('6')) {
        if (cleanNumber.length >= 4) {
          final firstFour = cleanNumber.substring(0, 4);
          if (firstFour == '6011' || firstFour == '6500') {
            detectedBrand = 'discover';
          }
        }
      } else {
        detectedBrand = '';
      }
    } else {
      detectedBrand = '';
    }
    notifyListeners();
  }

  String? validateCardNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Card number is required';
    }

    // Remove spaces for validation
    final cleanNumber = value.replaceAll(' ', '');

    // Check if all characters are digits
    if (!RegExp(r'^\d+$').hasMatch(cleanNumber)) {
      return 'Invalid card number';
    }

    // Check length based on card type
    if (detectedBrand == 'amex') {
      if (cleanNumber.length != 15) {
        return 'American Express cards must have 15 digits';
      }
    } else {
      if (cleanNumber.length != 16) {
        return 'Card number must have 16 digits';
      }
    }

    // Simple Luhn algorithm validation
    if (!_isValidLuhn(cleanNumber)) {
      return 'Invalid card number';
    }

    return null;
  }

  String? validateExpiryDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Expiry date is required';
    }

    if (!value.contains('/') || value.length != 5) {
      return 'Use MM/YY format';
    }

    final parts = value.split('/');
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);

    if (month == null || year == null) {
      return 'Invalid date';
    }

    if (month < 1 || month > 12) {
      return 'Invalid month';
    }

    // Check if card is expired
    final now = DateTime.now();
    final currentYear = now.year % 100; // Get last 2 digits
    final currentMonth = now.month;

    if (year < currentYear || (year == currentYear && month < currentMonth)) {
      return 'Card has expired';
    }

    return null;
  }

  String? validateCVV(String? value) {
    if (value == null || value.isEmpty) {
      return 'CVV is required';
    }

    // American Express has 4-digit CVV, others have 3
    if (detectedBrand == 'amex') {
      if (value.length != 4) {
        return 'CVV must be 4 digits';
      }
    } else {
      if (value.length != 3) {
        return 'CVV must be 3 digits';
      }
    }

    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'CVV must contain only digits';
    }

    return null;
  }

  // Luhn algorithm for card validation
  bool _isValidLuhn(String cardNumber) {
    int sum = 0;
    bool alternate = false;

    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cardNumber[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  Future<void> saveCard(BuildContext context) async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    isLoading = true;
    notifyListeners();

    try {
      // If this is set as default, update other cards
      if (isDefault) {
        final batch = _firestore.batch();

        // First, set all existing cards to non-default
        final existingCards = await _firestore
            .collection('users')
            .doc(userId)
            .collection('paymentCards')
            .get();

        for (var doc in existingCards.docs) {
          batch.update(doc.reference, {'isDefault': false});
        }

        // Add the new card
        final newCardRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('paymentCards')
            .doc();

        batch.set(newCardRef, {
          'cardNumber': _maskCardNumber(cardNumberController.text),
          'cardHolderName': cardHolderNameController.text.trim(),
          'expiryDate': expiryDateController.text,
          'brand': detectedBrand.isEmpty ? 'other' : detectedBrand,
          'isDefault': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();
      } else {
        // Just add the card
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('paymentCards')
            .add({
          'cardNumber': _maskCardNumber(cardNumberController.text),
          'cardHolderName': cardHolderNameController.text.trim(),
          'expiryDate': expiryDateController.text,
          'brand': detectedBrand.isEmpty ? 'other' : detectedBrand,
          'isDefault': isDefault,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Check if widget is still mounted before using context
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card added successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      // Check if widget is still mounted before using context
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding card: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      isLoading = false;
      // Only notify listeners if the controller hasn't been disposed
      if (!hasListeners) return;
      notifyListeners();
    }
  }

  String _maskCardNumber(String cardNumber) {
    // Store only last 4 digits for security
    final clean = cardNumber.replaceAll(' ', '');
    if (clean.length >= 4) {
      final lastFour = clean.substring(clean.length - 4);
      return '**** **** **** $lastFour';
    }
    return '**** **** **** ****';
  }
}