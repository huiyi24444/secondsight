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

                print('Fetched shipment: ${shipment?.shipAddress}, ${shipment?.shippedDate}, ${shipment?.trackingNumber}');


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

            return _buildBottomButtons(order);
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
          Row(
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
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8E6CEF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (shipment != null)
            ...[
              _buildSummaryRow('Shipping Address', shipment.shipAddress),
              _buildSummaryRow(
                'Shipped Date',
                _controller.getFormattedDate(shipment.shippedDate),
              ),
              _buildSummaryRow('Tracking Number', shipment.trackingNumber),
            ],
          _buildSummaryRow(
            'Eligible for Return',
            order.eligibilityForReturn ? 'Yes' : 'No',
          ),
        ],
      ),
    );
  }


  Widget _buildSummaryRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: isHighlight ? const Color(0xFF8E6CEF) : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildBottomButtons(OrdersModel order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _buildReturnRefundButton(order),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRateButton(order),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReturnRefundButton(OrdersModel order) {
    final bool isEligible = _controller.isEligibleForReturn(order);

    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isEligible
            ? () => _handleReturnRefund(order)
            : () => _showIneligibleDialog(),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEligible ? Colors.white : Colors.grey[100],
          foregroundColor: isEligible ? Colors.redAccent : Colors.grey[400],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isEligible ? Colors.redAccent : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(
          _controller.getReturnButtonText(order),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isEligible ? Colors.redAccent : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildRateButton(OrdersModel order) {
    final bool canRate = _controller.canRateOrder(order);

    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: canRate ? () => _handleRate(order) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canRate ? const Color(0xFF8E6CEF) : Colors.grey[300],
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(
          _controller.getRatingButtonText(order),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: canRate ? Colors.white : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  void _handleReturnRefund(OrdersModel order) {
    _showProductSelectionDialog(order);
  }

  void _handleRate(OrdersModel order) {
    showRatingDialog(context: context, order: order);
  }

  void _showProductSelectionDialog(OrdersModel order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Item to Return',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: _controller.getOrderProductsStream(),
                builder: (context, productsSnapshot) {
                  if (!productsSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8E6CEF),
                      ),
                    );
                  }

                  final products = productsSnapshot.data!.docs;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final data = products[index].data() as Map<String, dynamic>;
                      final orderProduct = _controller.createOrderProductFromDocument(data);
                      final productRef = orderProduct.productID;
                      final orderProductId = products[index].id;

                      return FutureBuilder<DocumentSnapshot>(
                        future: _controller.getProductDocument(productRef),
                        builder: (context, productSnapshot) {
                          if (!productSnapshot.hasData) {
                            return const SizedBox(
                              height: 60,
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

                          return _buildProductSelectionItem(
                              orderProduct,
                              productURL,
                              productName,
                              orderProductId
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductSelectionItem(
      OrderProductModel orderProduct,
      String productURL,
      String productName,
      String orderProductId
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.network(
              productURL,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                    size: 20,
                  ),
                );
              },
            ),
          ),
        ),
        title: Text(
          productName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _controller.getProductSummaryText(
              orderProduct.productQuantity,
              orderProduct.totalPrice
          ),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Color(0xFF8E6CEF),
        ),
        onTap: () {
          Navigator.pop(context);
          _navigateToReturnRequest(orderProductId);
        },
      ),
    );
  }

  void _navigateToReturnRequest(String orderProductId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReturnRequestView(
          orderId: widget.orderId,
          userId: widget.userId,
          orderProductId: orderProductId,
        ),
      ),
    );
  }

  void _showIneligibleDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.orange[600],
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Return Not Available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            _controller.getReturnIneligibilityMessage(),
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8E6CEF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }


}