// File: lib/views/checkout_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'order_success_view.dart';

class CheckoutView extends StatefulWidget {
  final double subtotal;
  final double shippingCost;
  final double tax;
  final double total;

  const CheckoutView({
    super.key,
    required this.subtotal,
    required this.shippingCost,
    required this.tax,
    required this.total,
  });

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  String? selectedAddress;
  String? selectedPaymentMethod;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_ios, size: 20),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Checkout',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                ],
              ),
            ),

            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Shipping Address
                    _buildCheckoutOption(
                      'Shipping Address',
                      'Add Shipping Address',
                      Icons.chevron_right,
                      onTap: () {
                        _showAddressSelection();
                      },
                    ),

                    Divider(height: 1),

                    // Payment Method
                    _buildCheckoutOption(
                      'Payment Method',
                      'Add Payment Method',
                      Icons.chevron_right,
                      onTap: () {
                        _showPaymentMethodSelection();
                      },
                    ),

                    Spacer(),

                    // Order Summary
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildSummaryRow('Subtotal', widget.subtotal),
                          _buildSummaryRow('Shipping Cost', widget.shippingCost),
                          _buildSummaryRow('Tax', widget.tax),
                          Divider(),
                          _buildSummaryRow('Total', widget.total, isTotal: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Place Order Button
            Container(
              margin: EdgeInsets.all(16),
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: selectedAddress != null && selectedPaymentMethod != null
                    ? () => _processPayment()
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '\$${widget.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      'Place Order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Home Indicator
            Container(
              width: 134,
              height: 5,
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutOption(String title, String subtitle, IconData icon, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      trailing: Icon(
        icon,
        color: Colors.grey[400],
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey[600],
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddressSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressSelectionSheet(
        onAddressSelected: (address) {
          setState(() {
            selectedAddress = address;
          });
        },
      ),
    );
  }

  void _showPaymentMethodSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentMethodSheet(
        onPaymentMethodSelected: (method) {
          setState(() {
            selectedPaymentMethod = method;
          });
        },
      ),
    );
  }

  Future<void> _processPayment() async {
    try {
      // Create payment intent on your backend
      final paymentIntent = await _createPaymentIntent();

      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          merchantDisplayName: 'Your Store Name',

        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Payment succeeded
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderSuccessScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _createPaymentIntent() async {
    final response = await http.post(
      Uri.parse('http://192.168.0.15:3000/create-payment-intent'), // Your PC's IP
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'amount': (widget.total * 100).round(),
        'currency': 'usd',
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }
}

class AddressSelectionSheet extends StatelessWidget {
  final Function(String) onAddressSelected;

  AddressSelectionSheet({required this.onAddressSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select Shipping Address',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildAddressOption(
                  '2715 Ash Dr, San Jose, South Dakota...',
                  true,
                      () {
                    onAddressSelected('2715 Ash Dr, San Jose, South Dakota');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressOption(String address, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Color(0xFF8B5CF6) : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(address),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Color(0xFF8B5CF6))
            : null,
        onTap: onTap,
      ),
    );
  }
}

class PaymentMethodSheet extends StatelessWidget {
  final Function(String) onPaymentMethodSelected;

  PaymentMethodSheet({required this.onPaymentMethodSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildPaymentOption(
                  '**** 4567',
                  'Visa',
                  true,
                      () {
                    onPaymentMethodSelected('**** 4567');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String cardNumber, String cardType, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Color(0xFF8B5CF6) : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              cardType,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(cardNumber),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Color(0xFF8B5CF6))
            : null,
        onTap: onTap,
      ),
    );
  }
}