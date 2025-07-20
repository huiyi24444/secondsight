import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

import '../../model/address_model.dart';
import '../../model/cart_item_model.dart';
import '../../model/order_model.dart';
import '../../model/order_product_model.dart';
import '../../model/payment_cards_model.dart';
import '../../model/shipment_model.dart';
import '../../services/stripe_service.dart';
import '../checkout/payment_cards_view.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/shipping_address_selection.dart';
import 'order_success_view.dart';

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
  AddressModel? selectedAddress;
  PaymentCard? selectedPaymentCard;
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    StripeService.initialize();
    _loadDefaultAddress();
    _loadDefaultPaymentCard();
  }

  Future<void> _loadDefaultAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('address')
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      final defaultAddress = AddressModel(
        fullName: data['fullName'] ?? '',
        phoneNum: data['phoneNum'] ?? 0,
        isDefault: data['isDefault'] ?? false,
        streetone: data['streetone'] ?? '',
        streettwo: data['streettwo'] ?? '',
        city: data['city'] ?? '',
        state: data['state'] ?? '',
        zipCode: data['zipCode']?.toString() ?? data['zipcode']?.toString() ?? '',
      );

      setState(() {
        selectedAddress = defaultAddress;
      });
    }
  }

  Future<void> _loadDefaultPaymentCard() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('paymentCards')
        .get();

    final cards = snapshot.docs.map((doc) => PaymentCard.fromDocument(doc)).toList();
    if (cards.isEmpty) return;

    final defaultCard = cards.firstWhere(
          (card) => card.isDefault,
      orElse: () => cards.first,
    );

    setState(() {
      selectedPaymentCard = defaultCard;
    });
  }

  String _formatAddress(AddressModel address) {
    final parts = <String>[];
    if (address.streetone.isNotEmpty) parts.add(address.streetone);
    if (address.streettwo.isNotEmpty) parts.add(address.streettwo);
    if (address.city.isNotEmpty) parts.add(address.city);
    if (address.state.isNotEmpty) parts.add(address.state);
    if (address.zipCode.isNotEmpty) parts.add(address.zipCode);
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text('Checkout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildCheckoutOption(
                      'Shipping Address',
                      selectedAddress != null ? _formatAddress(selectedAddress!) : 'Add Shipping Address',
                      Icons.chevron_right,
                      onTap: _showAddressSelection,
                    ),
                    const Divider(height: 1),
                    _buildCheckoutOption(
                      'Payment Card',
                      selectedPaymentCard != null
                          ? '**** ${selectedPaymentCard!.lastFour.substring(selectedPaymentCard!.lastFour.length - 4)}'
                          : 'Add Payment Card',
                      Icons.chevron_right,
                      onTap: _showPaymentCardSelection,
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildSummaryRow('Subtotal', widget.subtotal),
                          _buildSummaryRow('Shipping Cost', widget.shippingCost),
                          const Divider(),
                          _buildSummaryRow('Total', widget.total, isTotal: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (selectedAddress != null && selectedPaymentCard != null && !_isProcessingPayment)
                    ? _processPayment
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isProcessingPayment
                    ? const SizedBox(
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
                    Text('RM${widget.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(width: 16),
                    const Text('Place Order',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutOption(String title, String subtitle, IconData icon, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      title: Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black)),
      trailing: Icon(icon, color: Colors.grey[400], size: 20),
      onTap: onTap,
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
                color: isTotal ? Colors.black : Colors.grey[600],
              )),
          Text('RM${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
                color: Colors.black,
              )),
        ],
      ),
    );
  }

  void _showAddressSelection() {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to select an address.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShippingAddressSelection(
        userId: currentUser.uid,
        initiallySelectedAddress: selectedAddress,
        onAddressSelected: (address) {
          setState(() {
            selectedAddress = address;
          });
        },
      ),
    );
  }


  void _showPaymentCardSelection() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentCardSheet(
        userId: userId,
        onPaymentCardSelected: (PaymentCard card) {
          setState(() {
            selectedPaymentCard = card;
          });
        },
      ),
    );
  }


  Future<void> _processPayment() async {
    setState(() => _isProcessingPayment = true);

    try {
      final result = await StripeService.processPaymentWithPaymentSheet(
        amount: widget.total,
        currency: 'MYR',
        merchantName: 'SecondSight',
      );

      if (!result.success) throw Exception(result.message);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // 👇 Generate shipment ID manually
      final shipmentId = FirebaseFirestore.instance.collection('shipment_id').doc().id;

      // 👇 Create the order with the shipmentID included
      final orderRef = await userRef.collection('order').add({
        'orderDate': Timestamp.fromDate(DateTime.now()),
        'orderStatus': 'to_ship',
        'totalAmount': widget.total,
        'eligibilityForReturn': true,
        'shipmentID': shipmentId,
        'payment': result.transactionId ?? 'unknown',
      });

      // 👇 Create shipment using the new ShipmentModel (with DateTime? shippedDate)
      final shipment = ShipmentModel(
        id: shipmentId,
        shippedDate: null,
        trackingNumber: null,
        shipAddress: selectedAddress != null ? _formatAddress(selectedAddress!) : 'Unknown address',
        fullName: selectedAddress?.fullName,
        phoneNum: selectedAddress?.phoneNum,
        streetone: selectedAddress?.streetone,
        streettwo: selectedAddress?.streettwo,
        city: selectedAddress?.city,
        state: selectedAddress?.state,
        zipCode: selectedAddress?.zipCode,
      );

      // 👇 Add shipment document to subcollection under order with specific ID
      await orderRef.collection('shipment').doc(shipmentId).set(shipment.toMap());

      // 👇 Add ordered products and update stock
      for (final item in widget.cartItems) {
        final productRef = FirebaseFirestore.instance.collection('products').doc(item.product.id);

        await orderRef.collection('orderProducts').add({
          'price': item.product.price,
          'productID': productRef,
          'productQuantity': item.quantity,
          'totalPrice': item.product.price * item.quantity,
        });

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(productRef);
          final data = snapshot.data() as Map<String, dynamic>;
          final currentStock = data['stockQuantity'] as int? ?? 0;
          final newStock = currentStock - item.quantity;
          if (newStock < 0) throw Exception('Insufficient stock');
          transaction.update(productRef, {
            'stockQuantity': newStock,
            if (newStock == 0) 'productStatus': 'sold',
          });
        });
      }

      // 👇 Navigate to success screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderSuccessScreen(orderId: orderRef.id, userId: user.uid),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }


}
