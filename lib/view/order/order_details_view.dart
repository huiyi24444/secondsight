// Updated order_details_view.dart with MVC pattern
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../controller/order/order_details_controller.dart';
import '../../model/order_model.dart';
import '../../model/order_product_model.dart';
import '../../model/shipment_model.dart';
import '../returnRefund/return_request_view.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/progress_stepper.dart';
import 'order_details_bottom.dart';
import 'order_notice.dart';
import 'order_rating_dialog.dart';
import 'package:intl/intl.dart';

class OrderDetailsView extends StatefulWidget {
  final String orderId;
  final String userId;

  const OrderDetailsView({
    super.key,
    required this.orderId,
    required this.userId,
  });

  @override
  State<OrderDetailsView> createState() => _OrderDetailsViewState();
}

class _OrderDetailsViewState extends State<OrderDetailsView> {
  late OrderDetailsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OrderDetailsController(
      orderId: widget.orderId,
      userId: widget.userId,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          leading: const CustomBackButton(),
          title: Text(
            'Order #${_controller.shortOrderId}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFFFAFAFA),
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _controller.getOrderStream(),
          builder: (context, orderSnapshot) {
            if (!orderSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF8E6CEF),
                ),
              );
            }

            final data = orderSnapshot.data!;
            final order = _controller.createOrderFromDocument(data);

            return FutureBuilder<ShipmentModel?>(
              future: _controller.fetchShipment(widget.userId, order.id, order.shipmentID),

              builder: (context, shipmentSnapshot) {
                if (shipmentSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8E6CEF),
                    ),
                  );
                }
                final shipment = shipmentSnapshot.data;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOrderStatusCard(order),
                      _buildProductsSection(),
                      _buildTotalSummary(order, shipment),
                      const SizedBox(height: 100),
                    ],
                  ),
                );
              },
            );
          },
        ),

        bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
          stream: _controller.getOrderStream(),
          builder: (context, orderSnapshot) {
            if (!orderSnapshot.hasData) {
              return const SizedBox.shrink();
            }

            final data = orderSnapshot.data!;
            final order = _controller.createOrderFromDocument(data);

            return OrderBottomButtons(
              order: order,
              controller: _controller,
              userId: widget.userId,
              orderId: widget.orderId,
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderStatusCard(OrdersModel order) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Check order status and show appropriate widget
          _buildStatusContent(order),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                _controller.formatOrderDate(order.orderDate),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusContent(OrdersModel order) {
    final String status = order.orderStatus.toLowerCase();

    switch (status) {
      case 'cancelled':
        return OrderStatusNotice(
          type: OrderNoticeType.cancelled,
          customMessage: 'This order has been cancelled. If you have any questions, please contact our support team.',
        );

      case 'pending payment':
      case 'pending_payment':
      case 'payment pending':
        return OrderStatusNotice(
          type: OrderNoticeType.pendingPayment,
          customMessage: 'Your order is waiting for payment confirmation. Please complete the payment to proceed.',
          onPaymentPressed: () => _handlePaymentAction(order),
        );

      default:
      // Show normal progress stepper for other statuses
        final config = _controller.getOrderStatusConfig(order.orderStatus);
        return ProgressStepper(
          title: config['title'],
          steps: config['steps'],
          currentStep: config['currentStep'],
        );
    }
  }

  void _handlePaymentAction(OrdersModel order) {
    // Handle payment action - you can implement navigation to payment screen
    // or show payment options dialog here
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Complete Payment',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Redirecting to payment gateway for order #${_controller.shortOrderId}...',
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Navigate to payment screen
                // Navigator.push(context, MaterialPageRoute(
                //   builder: (context) => PaymentScreen(orderId: order.orderID),
                // ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E6CEF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
  }


  Widget _buildProductsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _controller.getOrderProductsStream(),
            builder: (context, productsSnapshot) {
              if (!productsSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF8E6CEF),
                  ),
                );
              }

              final products = productsSnapshot.data!.docs;

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: products.length,
                separatorBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.grey[200]),
                ),
                itemBuilder: (context, index) {
                  final data = products[index].data() as Map<String, dynamic>;
                  final orderProduct = _controller.createOrderProductFromDocument(data);
                  final productRef = orderProduct.productID;

                  return FutureBuilder<DocumentSnapshot>(
                    future: _controller.getProductDocument(productRef),
                    builder: (context, productSnapshot) {
                      if (!productSnapshot.hasData) {
                        return const SizedBox(
                          height: 80,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF8E6CEF),
                            ),
                          ),
                        );
                      }
                      final product = productSnapshot.data!.data() as Map<String, dynamic>?;
                      final productURL = _controller.extractProductImageUrl(product);
                      final productName = _controller.extractProductName(product);
                      return _buildProductItem(orderProduct, productURL, productName);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(OrderProductModel orderProduct, String productURL, String productName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.network(
              productURL,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _controller.getProductQuantityText(orderProduct.productQuantity),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _controller.getFormattedProductPrice(orderProduct.totalPrice),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalSummary(OrdersModel order, ShipmentModel? shipment) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Amount Section
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(  // Shipping Cost Row (add this)
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Shipping Cost',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'RM 8.00',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4), // spacing between shipping and total
                Row( // Existing Total Amount Row
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _controller.getFormattedTotalAmount(order.totalAmount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8E6CEF),
                      ),
                    ),
                  ],
                ),
              ],
            ),

          ),
          const SizedBox(height: 16),

          // Shipment Details
          if (shipment != null) ...[
            // Shipping Address with special layout
            _buildShippingAddressSection(shipment.shipAddress),
            const SizedBox(height: 16),

            // Other shipment details in a grid layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildCompactInfoCard(
                    'Shipped Date',
                    shipment.shippedDate != null
                        ? _controller.getFormattedDate(shipment.shippedDate!)
                        : 'To be updated',
                    isPlaceholder: shipment.shippedDate == null,
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCompactInfoCard(
                    'Return Eligible',
                    order.eligibilityForReturn ? 'Yes' : 'No',
                    icon: Icons.replay_outlined,
                    valueColor: order.eligibilityForReturn ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tracking Number with full width
            _buildTrackingNumberCard(
              shipment.trackingNumber,
            ),
          ] else ...[
            // If no shipment, just show return eligibility
            _buildCompactInfoCard(
              'Eligible for Return',
              order.eligibilityForReturn ? 'Yes' : 'No',
              icon: Icons.replay_outlined,
              valueColor: order.eligibilityForReturn ? Colors.green : Colors.grey,
            ),
          ],
        ],
      ),
    );
  }

// Special widget for shipping address
  Widget _buildShippingAddressSection(String address) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF8E6CEF).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8E6CEF).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 18,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                'Shipping Address',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            address,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

// Compact info card for other details
  Widget _buildCompactInfoCard(
      String label,
      String value, {
        bool isPlaceholder = false,
        IconData? icon,
        Color? valueColor,
      }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isPlaceholder
                  ? Colors.grey[400]
                  : valueColor ?? Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

// Special widget for tracking number
  Widget _buildTrackingNumberCard(String? trackingNumber) {
    final hasTracking = trackingNumber != null && trackingNumber.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasTracking
            ? const Color(0xFF8E6CEF).withOpacity(0.05)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: hasTracking
            ? Border.all(
          color: const Color(0xFF8E6CEF).withOpacity(0.1),
          width: 1,
        )
            : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 20,
            color: hasTracking
                ? const Color(0xFF8E6CEF)
                : Colors.grey[400],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tracking Number',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasTracking ? trackingNumber : 'To be updated',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: hasTracking
                        ? const Color(0xFF8E6CEF)
                        : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          if (hasTracking)
            Icon(
              Icons.copy_outlined,
              size: 18,
              color: Colors.grey[400],
            ),
        ],
      ),
    );
  }
}