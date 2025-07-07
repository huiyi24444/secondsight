import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:secondsight/view/checkout/payment_method_view.dart';
import 'package:secondsight/view/widgets/shipping_address_selection.dart';
import '../../model/cart_item_model.dart';
import '../../model/order_product_model.dart';
import '../../model/shipment_model.dart';
import '../../services/stripe_service.dart';
import 'order_success_view.dart';
import '../../model/order_model.dart';

class CheckoutView extends StatefulWidget {
  final double subtotal;
  final double shippingCost;
  final double total;
  final List<CartItem> cartItems;

  const CheckoutView({
    super.key,
    required this.subtotal,
    required this.shippingCost,
    required this.total,
    required this.cartItems,
  });

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  String? selectedAddress;
  String? selectedPaymentMethod;
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    // Initialize Stripe when the checkout view loads
    StripeService.initialize();
  }

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
                      selectedAddress ?? 'Add Shipping Address',
                      Icons.chevron_right,
                      onTap: () {
                        _showAddressSelection();
                      },
                    ),

                    Divider(height: 1),

                    // Payment Method
                    _buildCheckoutOption(
                      'Payment Method',
                      selectedPaymentMethod ?? 'Add Payment Method',
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
                onPressed: (selectedAddress != null &&
                    selectedPaymentMethod != null &&
                    !_isProcessingPayment)
                    ? () => _processPayment()
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isProcessingPayment
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                )
                    : Row(
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
      builder: (context) => ShippingAddressSelection(
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
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // 1. Process payment
      final result = await StripeService.processPaymentWithPaymentSheet(
        amount: widget.total,
        currency: 'USD',
        merchantName: 'SecondSight',
      );

      if (!result.success) {
        throw Exception(result.message);
      }

      // 2. Get user info
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // 3. Create OrdersModel
      final orderData = OrdersModel(
        id: '', // Firestore will auto-generate
        customerId: user.uid,
        orderDate: DateTime.now(),
        orderStatus: 'processing',
        totalAmount: widget.total,
        eligibilityForReturn: true,
        shipmentID: null, // Add later
        payment: result.transactionId ?? 'unknown',
      );

      // 4. Add order document
      final orderRef = await userRef.collection('order').add({
        'orderDate': Timestamp.fromDate(orderData.orderDate),
        'orderStatus': orderData.orderStatus,
        'totalAmount': orderData.totalAmount,
        'eligibilityForReturn': orderData.eligibilityForReturn,
        'shipmentID': orderData.shipmentID ?? '',
        'payment': orderData.payment,
      });

      // 5. Add order products and update stock quantities
      for (final item in widget.cartItems) {
        final orderProduct = OrderProductModel(
          price: item.product.price,
          productID: FirebaseFirestore.instance.collection('products').doc(item.product.id),
          productQuantity: item.quantity,
          totalPrice: item.product.price * item.quantity,
        );

        await orderRef.collection('orderProducts').add({
          'price': orderProduct.price,
          'productID': orderProduct.productID,
          'productQuantity': orderProduct.productQuantity,
          'totalPrice': orderProduct.totalPrice,
        });

        // Update product stock quantity
        final productRef = FirebaseFirestore.instance.collection('products').doc(item.product.id);

        // Use a transaction to ensure atomic updates
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // Get the current product document
          final productSnapshot = await transaction.get(productRef);

          if (!productSnapshot.exists) {
            throw Exception('Product ${item.product.id} not found');
          }

          final productData = productSnapshot.data() as Map<String, dynamic>;
          final currentStock = productData['stockQuantity'] as int? ?? 0;

          // Calculate new stock quantity
          final newStock = currentStock - item.quantity;

          if (newStock < 0) {
            throw Exception('Insufficient stock for product ${item.product.id}');
          }

          // Prepare update data
          final updateData = <String, dynamic>{
            'stockQuantity': newStock,
          };

          // If stock reaches 0, update product status to 'sold'
          if (newStock == 0) {
            updateData['productStatus'] = 'sold';
          }

          // Update the product document
          transaction.update(productRef, updateData);
        });
      }

      // 6. Add shipment document
      final shipment = ShipmentModel(
        id: '', // Firestore will auto-generate
        shipAddress: selectedAddress ?? 'Unknown address',
        shippedDate: null,
        trackingNumber: null,
      );

      final shipmentRef = await orderRef.collection('shipment').add(shipment.toMap());

      print('Saving shipment map: ${shipment.toMap()}');

      // 7. Update the order document with shipment ID
      await orderRef.update({
        'shipmentID': shipmentRef.id,
      });

      // 8. Go to success screen with orderId
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderSuccessScreen(
              orderId: orderRef.id,
              userId: user.uid,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }
}
