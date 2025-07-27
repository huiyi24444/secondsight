// FILE: order_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:secondsight/view/widgets/order_status_utils.dart';
import 'package:secondsight/web/admin/product/admin_product.dart';
import '../../../admin_main.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../../model/shipment_model.dart';
import '../../../model/payment_cards_model.dart';
import '../../../view/widgets/product_status_utils.dart';
import '../../../view/widgets/user_utils.dart';
import '../customer/admin_customer.dart';
import '../returnrefund/admin_return.dart';
import '../widget/sidebar.dart';
import '../widget/topbar.dart';
import 'admin_order.dart';

class OrderDetailsPage extends StatefulWidget {
  final OrdersModel order;
  final List<OrderProductModel> products;
  final Map<String, Map<String, dynamic>> productDetails;
  final Map<String, String> customerNames;
  final FirebaseFirestore firestore;
  final Future<void> Function() onOrdersReload;

  const OrderDetailsPage({
    Key? key,
    required this.order,
    required this.products,
    required this.productDetails,
    required this.customerNames,
    required this.firestore,
    required this.onOrdersReload,
  }) : super(key: key);

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  late String currentStatus;
  ShipmentModel? shipment;
  PaymentCard? paymentCard;
  bool isLoading = true;
  String currentPage = 'orders';

  // Define allowed status transitions
  static const Map<String, List<String>> allowedTransitions = {
    'to_ship': ['to_receive', 'canceled'],
    'to_receive': ['completed', 'canceled'],
    'completed': [],
    'canceled': [],
  };

  @override
  void initState() {
    super.initState();
    currentStatus = widget.order.orderStatus;
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    await Future.wait([
      _fetchShipmentData(),
      _fetchPaymentData(),
    ]);
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _fetchShipmentData() async {
    try {
      final shipmentSnapshot = await widget.firestore
          .collection('users')
          .doc(widget.order.customerId)
          .collection('order')
          .doc(widget.order.id)
          .collection('shipment')
          .get();
      if (shipmentSnapshot.docs.isNotEmpty) {
        shipment = ShipmentModel.fromMap(
          shipmentSnapshot.docs.first.data(),
          shipmentSnapshot.docs.first.id,
        );
      }
    } catch (e) {
      debugPrint('Error fetching shipment: $e');
    }
  }

  Future<void> _fetchPaymentData() async {
    try {
      if (widget.order.payment != null && widget.order.payment != 'Pending') {
        final paymentMethodsSnapshot = await widget.firestore
            .collection('users')
            .doc(widget.order.customerId)
            .collection('paymentMethods')
            .get();

        if (paymentMethodsSnapshot.docs.isNotEmpty) {
          QueryDocumentSnapshot<Map<String, dynamic>>? defaultPaymentDoc;

          for (var doc in paymentMethodsSnapshot.docs) {
            if (doc.data()['isDefault'] == true) {
              defaultPaymentDoc = doc;
              break;
            }
          }

          defaultPaymentDoc ??= paymentMethodsSnapshot.docs.first;
          paymentCard = PaymentCard.fromDocument(defaultPaymentDoc);
        }
      }
    } catch (e) {
      debugPrint('Error fetching payment card: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Sidebar
          AdminSidebar(
            currentPage: currentPage,
            onPageChanged: (String page) {
              // Handle navigation based on selected page
              switch (page) {
                case 'dashboard':
                // Navigate to dashboard - since we're in a sub-page, we go back to main
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => AdminNavigator()),
                        (route) => false,
                  );
                  break;
                case 'products':
                // Already on products page, might want to go back to product list
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => ProductManagementPage()),
                  );
                  break;
                case 'orders':
                // Navigate to order management
                  Navigator.pop(context);
                  break;
                case 'returns':
                // Navigate to return management
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => ReturnManagementPage()),
                  );
                  break;
                case 'customers':
                // Navigate to customer management
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => CustomerManagementPage()),
                  );
                  break;
                case 'reports':
                // Navigate to reports - you'll need to create this page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reports page not implemented yet')),
                  );
                  break;
              }
            },
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                CustomTopBar(
                  title: 'Order',
                  subtitle: 'Order Details',
                ),
                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12.0),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section with Order ID, Status, and Delete Button
          _buildHeaderSection(),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column - Main Content (70%)
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMainOrderInfo(),
                    const SizedBox(height: 20),
                    _buildOrderSummaryCard(),
                    const SizedBox(height: 20),
                    _buildOrderTimeline(),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Right Column - Supporting Details (30%)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildPaymentInfoCard(),
                    const SizedBox(height: 16),
                    if (shipment != null) _buildShipmentInfoCard(),
                    const SizedBox(height: 16),
                    _buildAddressInfoCard(),
                    const SizedBox(height: 16),
                    _buildCustomerInfoCard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Order ID and Status
          Expanded(
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${widget.order.shortOrderId}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.order.orderDate}',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: OrderStatusUtils.getStatusColor(currentStatus).withOpacity(0.1),
                    border: Border.all(color: OrderStatusUtils.getStatusColor(currentStatus)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButton<String>(
                    value: currentStatus,
                    underline: const SizedBox(),
                    isDense: true,
                    items: _getAvailableStatuses(currentStatus)
                        .map((status) => DropdownMenuItem(
                      value: status,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: OrderStatusUtils.getStatusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            OrderStatusUtils.formatStatus(status),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ))
                        .toList(),
                    onChanged: _handleStatusChange,
                  ),
                ),
              ],
            ),
          ),
          // Delete Button
          Container(
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: TextButton.icon(
              onPressed: () {
                if (widget.order.orderStatus == 'completed' || widget.order.orderStatus == 'to_receive') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cannot delete ${OrderStatusUtils.formatStatus(widget.order.orderStatus)} orders'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                _showDeleteConfirmationDialog();
              },
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              label: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 13)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainOrderInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF7C3AED),
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Order Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  'Order Date',
                  _formatDate(widget.order.orderDate),
                  Icons.calendar_today,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoTile(
                  'Customer',
                  widget.customerNames[widget.order.customerId] ?? 'Unknown',
                  Icons.person,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoTile(
                  'Return Eligible',
                  widget.order.eligibilityForReturn ? 'Yes' : 'No',
                  Icons.assignment_return,
                  widget.order.eligibilityForReturn ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    const double shippingFee = 8.00;
    final double subtotal = widget.products.fold(
        0,
            (sum, product) => sum + product.totalPrice
    );
    final double grandTotal = subtotal + shippingFee;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C3AED).withOpacity(0.1),
                  const Color(0xFF7C3AED).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3AED),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.order.orderStatus.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Products Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'ITEM DESCRIPTION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'SKU',
                    textAlign: TextAlign.center, // ADD THIS
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'QTY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'PRICE (Per Unit)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'TOTAL',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],

            ),
          ),

          // Product Items
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.products.length,
            itemBuilder: (context, index) {
              final product = widget.products[index];
              final productId = (product.productID as DocumentReference).id;
              final details = widget.productDetails[productId] ?? {};
              final imageUrl = details['imageUrl'] as String?;
              final productName = details['name'] as String? ?? 'Unknown Product';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[200]!,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Product Image and Name
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: (imageUrl?.isNotEmpty ?? false)
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.image, color: Colors.grey[400], size: 20),
                              ),
                            )
                                : Icon(Icons.image, color: Colors.grey[400], size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              productName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    //sku
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${ProductStatusUtils.shortProductId(product.productID.id)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),

                    // Quantity
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${product.productQuantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    // Unit Price
                    Expanded(
                      flex: 2,
                      child: Text(
                        'RM ${product.price.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    // Total Price
                    Expanded(
                      flex: 2,
                      child: Text(
                        'RM ${product.totalPrice.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Summary Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Subtotal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      'RM ${subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Shipping Fee
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Shipping Fee',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'RM ${shippingFee.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Divider
                Divider(
                  color: Colors.grey[300],
                  thickness: 1,
                ),
                const SizedBox(height: 16),

                // Grand Total
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF7C3AED).withOpacity(0.1),
                        const Color(0xFF7C3AED).withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF7C3AED).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet,
                              color: Color(0xFF7C3AED),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'TOTAL AMOUNT',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'RM ${grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED),
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


  Widget _buildOrderTimeline() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.timeline,
                  color: Colors.blue,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Order Timeline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: _buildTimelineItems(),
          ),
        ],
      ),
    );
  }

  // Right Column Cards - Smaller and more compact

  Widget _buildPaymentInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  color: Colors.green,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Payment',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.order.payment ?? 'Pending',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (paymentCard != null) ...[
            const SizedBox(height: 4),
            Text(
              '•••• •••• •••• ${paymentCard!.lastFour}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShipmentInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.local_shipping,
                  color: Colors.blue,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Shipment Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (shipment?.trackingNumber?.isNotEmpty ?? false) ...[
            Text(
              'Tracking: ${shipment!.trackingNumber!}',
              style: const TextStyle(
                fontSize: 15,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (shipment?.shippedDate != null) ...[
            Text(
              'Shipped: ${_formatDate(shipment!.shippedDate!)}',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
            ),
          ] else ...[
            Text(
              'Not yet shipped',
              style: TextStyle(
                fontSize: 15,
                color: Colors.orange[600],
              ),
            ),
          ],
          const SizedBox(height: 4),
          if (shipment?.fullName?.isNotEmpty ?? false) ...[
            Text(
              'To: ${shipment!.fullName!}',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.local_shipping,
                  color: Colors.blue,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Address Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (shipment?.fullName?.isNotEmpty ?? false) ...[
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '${shipment!.fullName!}',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          if (shipment?.phoneNum != null) ...[
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  '${shipment!.phoneNum}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (shipment?.streetone?.isNotEmpty ?? false) ...[
            Text(
              '${shipment!.streetone}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (shipment?.streettwo?.isNotEmpty ?? false) ...[
            Text(
              '${shipment!.streettwo}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
          ],
          if ((shipment?.city?.isNotEmpty ?? false) ||
              (shipment?.state?.isNotEmpty ?? false) ||
              (shipment?.zipCode?.isNotEmpty ?? false)) ...[
            Text(
              '${shipment?.city ?? ""}${(shipment?.city?.isNotEmpty ?? false) && (shipment?.state?.isNotEmpty ?? false) ? ", " : ""}${shipment?.state ?? ""} ${shipment?.zipCode ?? ""}'.trim(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.purple,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Customer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.customerNames[widget.order.customerId] ?? 'Unknown Customer',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
    'User ID: ${shortUserId(widget.order.customerId ?? "")}',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // Timeline helper methods
  List<Widget> _buildTimelineItems() {
    List<Widget> timelineItems = [];

    // Order Created (always present)
    timelineItems.add(_buildTimelineItem(
      'Order Created',
      widget.order.orderDate,
      Icons.shopping_cart,
      Colors.grey[700]!,
      isCompleted: true,
      isFirst: true,
    ));

    // Order Confirmed
    if (widget.order.confirmedDate != null) {
      timelineItems.add(_buildTimelineItem(
        'Order Confirmed',
        widget.order.confirmedDate!,
        Icons.check_circle,
        Colors.grey[700]!,
        isCompleted: true,
      ));
    } else if (widget.order.orderStatus != 'canceled') {
      timelineItems.add(_buildTimelineItem(
        'Order Confirmed',
        null,
        Icons.check_circle_outline,
        Colors.grey[400]!,
        isCompleted: false,
      ));
    }

    // To Ship
    if (widget.order.toShipDate != null) {
      timelineItems.add(_buildTimelineItem(
        'Ready to Ship',
        widget.order.toShipDate!,
        Icons.inventory,
        Colors.grey[700]!,
        isCompleted: true,
      ));
    } else if (['to_ship', 'to_receive', 'completed'].contains(widget.order.orderStatus)) {
      timelineItems.add(_buildTimelineItem(
        'Ready to Ship',
        null,
        Icons.inventory_outlined,
        Colors.grey[400]!,
        isCompleted: false,
      ));
    }

    // To Receive (Shipped)
    if (widget.order.toReceiveDate != null) {
      timelineItems.add(_buildTimelineItem(
        'Shipped',
        widget.order.toReceiveDate!,
        Icons.local_shipping,
        Colors.grey[700]!,
        isCompleted: true,
      ));
    } else if (['to_receive', 'completed'].contains(widget.order.orderStatus)) {
      timelineItems.add(_buildTimelineItem(
        'Shipped',
        null,
        Icons.local_shipping_outlined,
        Colors.grey[400]!,
        isCompleted: false,
      ));
    }

    // Completed or Cancelled
    if (widget.order.completedDate != null) {
      timelineItems.add(_buildTimelineItem(
        'Delivered',
        widget.order.completedDate!,
        Icons.done_all,
        Colors.green[700]!,
        isCompleted: true,
        isLast: true,
      ));
    } else if (widget.order.cancelledDate != null) {
      timelineItems.add(_buildTimelineItem(
        'Cancelled',
        widget.order.cancelledDate!,
        Icons.cancel,
        Colors.red[700]!,
        isCompleted: true,
        isLast: true,
      ));
    } else if (widget.order.orderStatus != 'canceled') {
      timelineItems.add(_buildTimelineItem(
        'Delivered',
        null,
        Icons.done_all_outlined,
        Colors.grey[400]!,
        isCompleted: false,
        isLast: true,
      ));
    }

    return timelineItems;
  }

  Widget _buildTimelineItem(
      String title,
      DateTime? date,
      IconData icon,
      Color color, {
        bool isCompleted = false,
        bool isFirst = false,
        bool isLast = false,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            if (!isFirst)
              Container(
                width: 2,
                height: 12,
                color: isCompleted ? Colors.grey[400] : Colors.grey[300],
              ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? color : Colors.grey[100],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? color : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 12,
                color: isCompleted ? Colors.white : Colors.grey[400],
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 20,
                color: isCompleted ? Colors.grey[400] : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 12),
        // Timeline content
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(top: 2, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.grey[800] : Colors.grey[500],
                  ),
                ),
                if (date != null)
                  Text(
                    _formatDateTime(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  )
                else if (!isCompleted)
                  Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Event handlers and utility methods
  void _handleStatusChange(String? newStatus) async {
    if (newStatus != null && newStatus != currentStatus) {
      if (!_isTransitionAllowed(currentStatus, newStatus)) {
        _showTransitionError(currentStatus, newStatus);
        return;
      }

      bool proceedWithUpdate = false;
      switch ('$currentStatus->$newStatus') {
        case 'to_ship->to_receive':
          proceedWithUpdate = await _handleShipToReceive();
          break;
        case 'to_receive->completed':
          proceedWithUpdate = await _handleReceiveToCompleted();
          break;
        case 'to_ship->canceled':
        case 'to_receive->canceled':
          proceedWithUpdate = await _handleCancellation();
          break;
        default:
          proceedWithUpdate = true;
      }

      if (proceedWithUpdate) {
        setState(() => currentStatus = newStatus);
        await _updateOrderStatus(newStatus);
        if (newStatus == 'to_receive') {
          await _fetchShipmentData();
        }
      }
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    try {
      await widget.firestore
          .collection('users')
          .doc(widget.order.customerId)
          .collection('order')
          .doc(widget.order.id)
          .update({'orderStatus': newStatus});
      await widget.onOrdersReload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order status updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating order: $e')),
        );
      }
    }
  }

  Future<bool> _handleShipToReceive() async {
    if (widget.order.payment == null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Payment Not Confirmed'),
          content: const Text(
              'This order does not have a recorded payment method. Are you sure you want to ship it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      ) ?? false;
      if (!proceed) return false;
    }

    bool isAddressComplete = shipment != null &&
        (shipment!.fullName?.isNotEmpty ?? false) &&
        (shipment!.phoneNum != null && shipment!.phoneNum! > 0) &&
        (shipment!.streetone?.isNotEmpty ?? false) &&
        (shipment!.city?.isNotEmpty ?? false) &&
        (shipment!.state?.isNotEmpty ?? false) &&
        (shipment!.zipCode?.isNotEmpty ?? false);

    if (!isAddressComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shipping address is incomplete. Please update customer information first.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (shipment?.trackingNumber == null || shipment!.trackingNumber!.isEmpty) {
      return await _showTrackingNumberDialog();
    }
    return true;
  }

  Future<bool> _handleReceiveToCompleted() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mark this order as completed?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. The order will be marked as delivered.',
                      style: TextStyle(fontSize: 13, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await widget.firestore
                  .collection('users')
                  .doc(widget.order.customerId)
                  .collection('order')
                  .doc(widget.order.id)
                  .update({
                'completedDate': Timestamp.now(),
              });
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete Order'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _handleCancellation() async {
    final reasonController = TextEditingController();
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentStatus == 'to_receive')
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This order has already been shipped. Cancellation may require return shipping.',
                        style: TextStyle(fontSize: 13, color: Colors.red[900]),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason *',
                hintText: 'Enter reason for cancellation',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a cancellation reason')),
                );
                return;
              }
              await widget.firestore
                  .collection('users')
                  .doc(widget.order.customerId)
                  .collection('order')
                  .doc(widget.order.id)
                  .update({
                'cancellationReason': reasonController.text.trim(),
                'canceledDate': Timestamp.now(),
              });
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _showTrackingNumberDialog() async {
    final trackingNumberController = TextEditingController();
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Tracking Number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A tracking number is required to update the status to "To Receive".',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: trackingNumberController,
              decoration: const InputDecoration(
                labelText: 'Tracking Number *',
                hintText: 'Enter tracking number',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'The shipped date will be set to current date/time.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (trackingNumberController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a tracking number')),
                );
                return;
              }
              try {
                final shipmentRef = widget.firestore
                    .collection('users')
                    .doc(widget.order.customerId)
                    .collection('order')
                    .doc(widget.order.id)
                    .collection('shipment');
                final snapshot = await shipmentRef.get();
                final updateData = {
                  'trackingNumber': trackingNumberController.text.trim(),
                  'shippedDate': Timestamp.now(),
                };
                if (snapshot.docs.isNotEmpty) {
                  await snapshot.docs.first.reference.update(updateData);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shipment document not found')),
                  );
                  Navigator.pop(context, false);
                  return;
                }
                if (context.mounted) {
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating tracking number: $e')),
                  );
                  Navigator.pop(context, false);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 36,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Order',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete this order?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.red[700],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        Navigator.pop(context);
                        try {
                          await widget.firestore
                              .collection('users')
                              .doc(widget.order.customerId)
                              .collection('order')
                              .doc(widget.order.id)
                              .delete();
                          await widget.onOrdersReload();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error deleting order: $e'))
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Delete Order', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Utility methods
  List<String> _getAvailableStatuses(String currentStatus) {
    List<String> statuses = [currentStatus];
    statuses.addAll(allowedTransitions[currentStatus] ?? []);
    return statuses;
  }

  bool _isTransitionAllowed(String fromStatus, String toStatus) {
    return allowedTransitions[fromStatus]?.contains(toStatus) ?? false;
  }

  void _showTransitionError(String fromStatus, String toStatus) {
    String message = '';
    if (fromStatus == 'completed') {
      message = 'Completed orders cannot be modified.';
    } else if (fromStatus == 'canceled') {
      message = 'Canceled orders cannot be reactivated.';
    } else if (fromStatus == 'to_receive' && toStatus == 'to_ship') {
      message = 'Cannot revert to "To Ship" once tracking number is provided.';
    } else {
      message = 'This status transition is not allowed.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final formatter = DateFormat('dd MMM yyyy');
    return formatter.format(dateTime);
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('dd MMM yyyy, HH:mm');
    return formatter.format(dateTime);
  }

}