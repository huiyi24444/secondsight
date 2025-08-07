// order_details_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controller/order/order_details_controller.dart';
import '../../model/cancel_model.dart';
import '../../model/order_model.dart';
import '../../model/order_product_model.dart';
import '../../model/payment_cards_model.dart';
import '../../model/shipment_model.dart';
import '../returnRefund/return_request_view.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/order_status_utils.dart';
import '../widgets/progress_stepper.dart';
import 'cancel_dialog.dart';
import 'cancel_unavail_dialog.dart';
import 'cancellation_details_widget.dart';
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
  final ValueNotifier<bool> _isProductsExpanded = ValueNotifier(false);


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
    _isProductsExpanded.dispose();
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

            actions: [
        // Wrap PopupMenuButton in StreamBuilder to access current order status
              // In your order details page
              StreamBuilder<DocumentSnapshot>(
                stream: _controller.getOrderStream(),
                builder: (context, orderSnapshot) {
                  return PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'cancel') {
                        if (orderSnapshot.hasData) {
                          final data = orderSnapshot.data!;
                          final order = _controller.createOrderFromDocument(data);

                          if (_controller.canCancelOrder(order)) {
                            showCancelOrderDialog(
                              context: context,
                              orderId: widget.orderId,
                              customerId: _controller.userId, // Add the customerId parameter
                              onCancel: () {
                                print('User chose to keep the order');
                              },
                              // Remove the onConfirm parameter entirely since the new dialog handles everything internally
                            );
                          } else {
                            showDialog(
                              context: context,
                              builder: (context) => const CancelUnavailableDialog(),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'cancel',
                        child: Text('Cancel order'),
                      ),
                    ],
                  );
                },
              )

            ],
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
                      _buildEnhancedOrderStatusCard(order),
                      _buildCancellationSection(order),
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

  Widget _buildCancellationSection(OrdersModel order) {
    debugPrint('_buildCancellationSection called for orderID: ${order.id}');
    debugPrint('orderStatus: "${order.orderStatus}"');
    debugPrint('cancelID: ${order.cancelID}');

    if (order.orderStatus.trim().toLowerCase() != 'cancelled' || order.cancelID == null) {
      debugPrint('Skipping _buildCancellationSection: Not cancelled or cancelID is null');
      return const SizedBox.shrink();
    }


    return FutureBuilder<CancellationModel?>(
      future: _controller.getCancellationDetails(order.cancelID!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('Loading cancellation details for cancelID: ${order.cancelID}');
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF8E6CEF),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Error in FutureBuilder for cancelID: ${order.cancelID} -> ${snapshot.error}');
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[600]),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Failed to load cancellation details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final cancellation = snapshot.data;
        if (cancellation == null) {
          debugPrint('CancellationModel is null for cancelID: ${order.cancelID}');
          return const SizedBox.shrink();
        }

        debugPrint('CancellationModel loaded for cancelID: ${order.cancelID}');
        return Column(
          children: [
            CancellationDetailsWidget(cancellation: cancellation),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }


  // NEW: Enhanced order status card with timeline
  Widget _buildEnhancedOrderStatusCard(OrdersModel order) {
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
          // Header
          Row(
            children: [
              const Text(
                'Order Timeline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: OrderStatusUtils.getStatusColor(order.orderStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  OrderStatusUtils.getStatusDisplayText(order.orderStatus),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: OrderStatusUtils.getStatusColor(order.orderStatus),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Status timeline
          _buildStatusTimeline(order),

          const SizedBox(height: 1),

          // Order date
          Row(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                'Order placed on ${_controller.formatOrderDate(order.orderDate)}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // NEW: Build status timeline widget
  Widget _buildStatusTimeline(OrdersModel order) {
    final statusSteps = _getOrderStatusSteps(order);

    return Column(
      children: List.generate(statusSteps.length, (index) {
        final step = statusSteps[index];
        final isLast = index == statusSteps.length - 1;
        final isActive = step['isActive'] as bool;
        final isCompleted = step['isCompleted'] as bool;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? step['color'] as Color
                        : Colors.grey[300],
                    border: isActive && !isCompleted
                        ? Border.all(
                      color: step['color'] as Color,
                      width: 2,
                    )
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                        : Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? step['color'] as Color
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: isCompleted
                        ? (statusSteps[index + 1]['isCompleted'] as bool
                        ? step['color'] as Color
                        : Colors.grey[300])
                        : Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // Status info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step['title'] as String,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isCompleted || isActive
                            ? Colors.black87
                            : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (step['date'] != null)
                      Text(
                        _controller.formatStatusDate(step['date'] as DateTime),
                        style: TextStyle(
                          fontSize: 13,
                          color: isCompleted || isActive
                              ? Colors.grey[600]
                              : Colors.grey[400],
                        ),
                      )
                    else
                      Text(
                        step['pendingText'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // NEW: Get order status steps with dates
  List<Map<String, dynamic>> _getOrderStatusSteps(OrdersModel order) {
    final status = order.orderStatus.toLowerCase();
    final steps = <Map<String, dynamic>>[];

    // Order Confirmed
    steps.add({
      'title': 'Order Confirmed',
      'date': order.confirmedDate ?? order.orderDate,
      'isCompleted': true,
      'isActive': false,
      'color': Color(0xFF8E6CEF),
      'pendingText': 'Pending confirmation',
    });

    // To Ship
    steps.add({
      'title': 'Ready to Ship',
      'date': order.toShipDate,
      'isCompleted': order.toShipDate != null,
      'isActive': status == 'to_ship',
      'color': Color(0xFF8E6CEF),
      'pendingText': 'Preparing your order',
    });

    // To Receive
    steps.add({
      'title': 'Shipped',
      'date': order.toReceiveDate,
      'isCompleted': order.toReceiveDate != null,
      'isActive': status == 'to_receive',
      'color': Color(0xFF8E6CEF),
      'pendingText': 'Waiting to be shipped',
    });

    // Completed or Cancelled
    if (status == 'cancelled' && order.cancelDate != null) {
      steps.add({
        'title': 'Order Cancelled',
        'date': order.cancelDate,
        'isCompleted': true,
        'isActive': false,
        'color': Colors.red,
        'pendingText': '',
      });
    } else {
      steps.add({
        'title': 'Delivered',
        'date': order.completedDate,
        'isCompleted': order.completedDate != null,
        'isActive': status == 'completed',
        'color': Color(0xFF8E6CEF),
        'pendingText': 'Out for delivery',
      });
    }

    return steps;
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
              final productCount = products.length;

              // Show first 3 items directly
              final visibleProducts = products.take(3).toList();
              final hiddenProducts = productCount > 3 ? products.skip(3).toList() : <QueryDocumentSnapshot>[];
              final hiddenFutures = hiddenProducts
                  .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final orderProduct = _controller.createOrderProductFromDocument(data);
                return _controller.getProductDocument(orderProduct.productID).then((productDoc) => {
                  'orderProduct': orderProduct,
                  'productData': productDoc.data() as Map<String, dynamic>?,
                });
              })
                  .toList();
              return Column(
                children: [
                  // Always visible products (first 3)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visibleProducts.length,
                    separatorBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: Colors.grey[200]),
                    ),
                    itemBuilder: (context, index) {
                      final data = visibleProducts[index].data() as Map<String, dynamic>;
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
                  ),

                  // Expandable section for additional items
                  if (hiddenFutures.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: Colors.grey[200]),
                    ),
                    _buildExpandableItemsSection(hiddenFutures),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableItemsSection(List<Future<Map<String, dynamic>>> futureProducts) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isProductsExpanded,
      builder: (context, expanded, _) {
        return Column(
          children: [
            if (!expanded) // ✅ Show toggle button only if not expanded
              InkWell(
                onTap: () => _isProductsExpanded.value = true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E6CEF).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF8E6CEF).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Show More Items',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E6CEF),
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF8E6CEF),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

            // Expandable product section
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: FutureBuilder<List<Map<String, dynamic>>>(
                future: Future.wait(futureProducts),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  final loaded = snapshot.data!;
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: loaded.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.grey[200]),
                    itemBuilder: (context, index) {
                      final orderProduct = loaded[index]['orderProduct'];
                      final product = loaded[index]['productData'];
                      final productURL = _controller.extractProductImageUrl(product);
                      final productName = _controller.extractProductName(product);
                      return _buildProductItem(orderProduct, productURL, productName);
                    },
                  );
                },
              ),
              crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        );
      },
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


            // Other shipment details in a grid layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildCompactInfoCard(
                    'Shipped Date',
                    shipment.shippedDate != null
                        ? DateFormat('MMM d, yyyy').format(shipment.shippedDate!)
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
            const SizedBox(height: 16),
            _buildShippingAddressSection(shipment),
            const SizedBox(height: 16),
            if (order.paymentCard != null) ...[
              FutureBuilder<PaymentCard?>(
                future: _controller.fetchPaymentCard(order.paymentCard!),
                builder: (context, paymentCardSnapshot) {
                  if (paymentCardSnapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      padding: const EdgeInsets.all(6),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF8E6CEF),
                        ),
                      ),
                    );
                  }

                  return _buildPaymentInformationSection(order, paymentCardSnapshot.data);
                },
              ),
            ],
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


  Widget _buildShippingAddressSection(ShipmentModel shipment) {
    final fullName = shipment.fullName?.trim() ?? '';
    final phoneNum = shipment.phoneNum ?? 0;

    final streetone = shipment.streetone?.trim() ?? '';
    final streettwo = shipment.streettwo?.trim() ?? '';
    final city = shipment.city?.trim() ?? '';
    final state = shipment.state?.trim() ?? '';
    final zipCode = shipment.zipCode?.trim() ?? '';

    final hasStructuredAddress = streetone.isNotEmpty || streettwo.isNotEmpty || city.isNotEmpty || state.isNotEmpty || zipCode.isNotEmpty;
    final fallbackAddress = shipment.shipAddress.trim();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8E6CEF).withOpacity(0.08),
            const Color(0xFF8E6CEF).withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8E6CEF).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF8E6CEF).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    size: 20,
                    color: Color(0xFF8E6CEF),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Delivery Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Recipient Name
                _buildInfoRow(
                  icon: Icons.person_outline,
                  label: 'Recipient',
                  value: fullName.isNotEmpty ? fullName : 'Unknown',
                  iconColor: const Color(0xFF8E6CEF),
                  isHighlighted: true,
                ),

                const SizedBox(height: 12),

                // Phone Number
                _buildInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Contact',
                  value: phoneNum > 0 ? '+60${phoneNum.toString()}' : 'No phone number',
                  iconColor: Colors.blue,
                ),

                const SizedBox(height: 12),

                // Full Address (structured or fallback)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: Colors.orange[700],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delivery Address',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasStructuredAddress
                                  ? '${streetone ?? ''} ${streettwo ?? ''}'.trim()
                                  : (fallbackAddress.isNotEmpty ? fallbackAddress : 'No address provided'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),

                            if (hasStructuredAddress) ...[
                              Text(
                                '$city, $state $zipCode',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildPaymentInformationSection(OrdersModel order, PaymentCard? paymentCard) {
    debugPrint(paymentCard != null
        ? 'Payment card received: ${paymentCard.brand}, ****${paymentCard.lastFour}'
        : 'Payment card is null');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300, // Or any color you want
          width: 1.2, // Adjust thickness as needed
        ),
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.payment,
                  size: 16,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Payment Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Payment Card
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Card',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),

                  if (paymentCard != null) ...[
                    Row(
                      children: [
                        Icon(
                          _getCardBrandIcon(paymentCard.brand),
                          size: 16,
                          color: _getCardBrandColor(paymentCard.brand),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${paymentCard.brand.toUpperCase()} •••• ${paymentCard.lastFour}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getCardBrandColor(paymentCard.brand),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(
                          Icons.credit_card_off,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Unavailable',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              // Transaction ID
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction ID',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.payment ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, size: 16, color: Colors.grey[600]),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: order.payment ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Transaction ID copied!')),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),


            ],
          ),

        ],
      ),
    );
  }


// Helper method to get card brand icon
  IconData _getCardBrandIcon(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return Icons.credit_card;
      case 'mastercard':
        return Icons.credit_card;
      case 'amex':
      case 'american express':
        return Icons.credit_card;
      case 'discover':
        return Icons.credit_card;
      default:
        return Icons.credit_card;
    }
  }

// Helper method to get card brand color
  Color _getCardBrandColor(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return const Color(0xFF1A1F71);
      case 'mastercard':
        return const Color(0xFFEB001B);
      case 'amex':
      case 'american express':
        return const Color(0xFF006FCF);
      case 'discover':
        return const Color(0xFFFF6000);
      default:
        return Colors.grey;
    }
  }

// Helper widget for info rows
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? iconColor.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
              ],
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