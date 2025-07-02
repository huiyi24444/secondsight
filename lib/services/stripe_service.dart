import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/material.dart';

class StripeService {
  static const String _publishableKey = 'pk_test_51RdqXPQSp3H55udZMewh3I9eilxrid02WSapRFKsq2hvoogenAFbSa5TnMbU4IOcRUZemfqBXPCvS1Rd4izRF2wf00KZr3wv10';
  static const String _secretKey = 'sk_test_51RdqXPQSp3H55udZbxSVOUrX8Inys1xEzDQMic5xYiJXfqVtzBGPGXSMsczIe6ZQjtbD2ZU4piNNzqNfqNAzUQ6V00dOZSTaRg';

  // Initialize Stripe
  static Future<void> initialize() async {
    Stripe.publishableKey = _publishableKey;
    await Stripe.instance.applySettings();
  }

  // Create payment intent on your server (for demo, direct call)
  static Future<Map<String, String>> createPaymentIntent(double amount, String currency) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': (amount * 100).toInt().toString(),
          'currency': currency.toLowerCase(),
          'automatic_payment_methods[enabled]': 'true',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'client_secret': data['client_secret'],
          'id': data['id'], // <-- this is your paymentIntentId
        };
      } else {
        throw Exception('Failed to create payment intent: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating payment intent: $e');
    }
  }


  // Process payment using PaymentSheet
  static Future<PaymentResult> processPaymentWithPaymentSheet({
    required double amount,
    required String currency,
    required String merchantName,
  }) async {
    try {
      final intent = await createPaymentIntent(amount, currency);
      final clientSecret = intent['client_secret']!;
      final paymentIntentId = intent['id']; // Extracted here

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantName,
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      return PaymentResult(
        success: true,
        message: 'Payment successful',
        transactionId: paymentIntentId, // <-- Use this for order model
      );
    } on StripeException catch (e) {
      return PaymentResult(
        success: false,
        message: e.error.message ?? 'Payment cancelled',
        errorCode: e.error.code?.toString(),
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        message: 'Payment failed: $e',
      );
    }
  }


  // Validate card number using Luhn algorithm
  static bool isValidCardNumber(String cardNumber) {
    String cleanNumber = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanNumber.length < 13 || cleanNumber.length > 19) {
      return false;
    }
    int sum = 0;
    bool alternate = false;
    for (int i = cleanNumber.length - 1; i >= 0; i--) {
      int n = int.parse(cleanNumber[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) {
          n = (n % 10) + 1;
        }
      }
      sum += n;
      alternate = !alternate;
    }
    return (sum % 10) == 0;
  }

  // Validate expiry date
  static bool isValidExpiryDate(String expiryMonth, String expiryYear) {
    try {
      int month = int.parse(expiryMonth);
      int year = int.parse(expiryYear);
      if (month < 1 || month > 12) return false;
      if (year < 100) year += 2000;
      DateTime now = DateTime.now();
      DateTime expiry = DateTime(year, month);
      return expiry.isAfter(now);
    } catch (e) {
      return false;
    }
  }

  // Validate CVC
  static bool isValidCVC(String cvc) {
    return cvc.length >= 3 && cvc.length <= 4 && RegExp(r'^\d+$').hasMatch(cvc);
  }
}

class PaymentResult {
  final bool success;
  final String message;
  final String? transactionId;
  final String? errorCode;

  PaymentResult({
    required this.success,
    required this.message,
    this.transactionId,
    this.errorCode,
  });
}