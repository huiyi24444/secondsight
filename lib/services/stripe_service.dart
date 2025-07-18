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

  // ======= EXISTING PAYMENT METHODS =======

  // Create payment intent (existing method for actual payments)
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
          'id': data['id'],
        };
      } else {
        throw Exception('Failed to create payment intent: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating payment intent: $e');
    }
  }

  // Process payment using PaymentSheet (existing method)
  static Future<PaymentResult> processPaymentWithPaymentSheet({
    required double amount,
    required String currency,
    required String merchantName,
  }) async {
    try {
      final intent = await createPaymentIntent(amount, currency);
      final clientSecret = intent['client_secret']!;
      final paymentIntentId = intent['id'];

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
        transactionId: paymentIntentId,
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

  // ======= NEW SETUP INTENT METHODS FOR SAVING CARDS =======

  // Create Stripe customer directly
  static Future<String> createCustomer({
    required String userId,
    required String email,
    required String name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/customers'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'email': email,
          'name': name,
          'metadata[user_id]': userId,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['id'];
      } else {
        throw Exception('Failed to create customer: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating customer: $e');
    }
  }

  // Create setup intent directly
  static Future<Map<String, String>> createSetupIntent({String? customerId}) async {
    try {
      final body = <String, String>{
        'payment_method_types[]': 'card',
        'usage': 'off_session',
      };

      if (customerId != null) {
        body['customer'] = customerId;
      }

      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/setup_intents'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'client_secret': data['client_secret'],
          'setup_intent_id': data['id'],
        };
      } else {
        throw Exception('Failed to create setup intent: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating setup intent: $e');
    }
  }

  // Get payment method details after setup
  static Future<Map<String, dynamic>> getPaymentMethodDetails(String setupIntentId) async {
    try {
      // First get the setup intent
      final setupResponse = await http.get(
        Uri.parse('https://api.stripe.com/v1/setup_intents/$setupIntentId'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
        },
      );

      if (setupResponse.statusCode == 200) {
        final setupData = json.decode(setupResponse.body);
        final paymentMethodId = setupData['payment_method'];

        if (paymentMethodId == null) {
          throw Exception('No payment method found');
        }

        // Now get the payment method details
        final pmResponse = await http.get(
          Uri.parse('https://api.stripe.com/v1/payment_methods/$paymentMethodId'),
          headers: {
            'Authorization': 'Bearer $_secretKey',
          },
        );

        if (pmResponse.statusCode == 200) {
          final pmData = json.decode(pmResponse.body);
          return {
            'id': pmData['id'],
            'type': pmData['type'],
            'card': {
              'brand': pmData['card']['brand'],
              'last4': pmData['card']['last4'],
              'exp_month': pmData['card']['exp_month'],
              'exp_year': pmData['card']['exp_year'],
            },
          };
        }
      }

      throw Exception('Failed to get payment method details');
    } catch (e) {
      throw Exception('Error getting payment method details: $e');
    }
  }

  // Save payment method using Setup Intent (main method for adding cards)
  static Future<SetupResult> savePaymentMethod({
    required String userId,
    String? customerId,
  }) async {
    try {
      // Create setup intent
      final setupIntent = await createSetupIntent(customerId: customerId);
      final clientSecret = setupIntent['client_secret']!;
      final setupIntentId = setupIntent['setup_intent_id']!;

      // Initialize payment sheet for setup (no payment)
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: clientSecret,
          merchantDisplayName: 'SecondSight Store',
          customerId: customerId,
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            primaryButton: PaymentSheetPrimaryButtonAppearance(
              colors: PaymentSheetPrimaryButtonTheme(
                light: PaymentSheetPrimaryButtonThemeColors(
                  background: Color(0xFF8E6CEF),
                ),
              ),
            ),
          ),
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Get payment method details
      final paymentMethodDetails = await getPaymentMethodDetails(setupIntentId);

      return SetupResult(
        success: true,
        message: 'Payment method saved successfully',
        paymentMethodDetails: paymentMethodDetails,
      );
    } on StripeException catch (e) {
      return SetupResult(
        success: false,
        message: e.error.message ?? 'Setup cancelled',
        errorCode: e.error.code?.toString(),
      );
    } catch (e) {
      return SetupResult(
        success: false,
        message: 'Setup failed: $e',
      );
    }
  }

  // Delete payment method
  static Future<bool> deletePaymentMethod(String paymentMethodId) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_methods/$paymentMethodId/detach'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting payment method: $e');
      return false;
    }
  }

  // ======= VALIDATION METHODS =======

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

// ======= RESULT CLASSES =======

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

class SetupResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? paymentMethodDetails;
  final String? errorCode;

  SetupResult({
    required this.success,
    required this.message,
    this.paymentMethodDetails,
    this.errorCode,
  });
}