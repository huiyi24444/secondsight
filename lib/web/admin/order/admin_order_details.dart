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
import '../../../view/returnRefund/return_request_details.dart';
import '../../../view/widgets/product_status_utils.dart';
import '../../../view/widgets/return_status_utils.dart';
import '../../../view/widgets/user_utils.dart';
import '../customer/admin_customer.dart';
import '../returnrefund/admin_return.dart';
import '../widget/sidebar.dart';
import '../widget/topbar.dart';
import 'admin_order.dart';
import 'admin_order_details_controller.dart';

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
  String? customerFullName;
  late OrderDetailsManagementController _controller;

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
    _controller = OrderDetailsManagementController(firestore: widget.firestore);
    currentStatus = widget.order.orderStatus;
    _loadOrderData();
    fetchCustomerName();
  }

  Future<void> _loadOrderData() async {
    final data = await _controller.loadOrderData(
      customerId: widget.order.customerId!,
      orderId: widget.order.id,
      paymentStatus: widget.order.payment,
    );

    setState(() {
      shipment = data.shipment;
      paymentCard = data.paymentCard;
      isLoading = false;
    });
  }


  Future<bool> hasReturnRequest(String orderId) async {
    final query = await FirebaseFirestore.instance
        .collection('returnRequests')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
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
                    MaterialPageRoute(
                      builder: (context) => ProductManagementPage(),
                    ),
                  );
                  break;
                case 'orders':
                  // Navigate to order management
                  Navigator.pop(context);
                  break;
                case 'returns':
                  // Navigate to return management
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => ReturnManagementPage(),
                    ),
                  );
                  break;
                case 'customers':
                  // Navigate to customer management
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => CustomerManagementPage(),
                    ),
                  );
                  break;
                case 'reports':
                  // Navigate to reports - you'll need to create this page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reports page not implemented yet'),
                    ),
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
                CustomTopBar(title: 'Order', subtitle: 'Order Details'),
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
                    const SizedBox(height: 16),
                    _buildReturnInfoCard(),
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
                      DateFormat('MMM dd, yyyy • hh:mm a').format(widget.order.orderDate),
                      // Output: Jul 17, 2025 • 01:06 AM
                    )
                  ],
                ),
                const SizedBox(width: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: OrderStatusUtils.getStatusColor(
                      currentStatus,
                    ).withOpacity(0.1),
                    border: Border.all(
                      color: OrderStatusUtils.getStatusColor(currentStatus),
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButton<String>(
                    value: currentStatus,
                    underline: const SizedBox(),
                    isDense: true,
                    items: _controller.getAvailableStatuses(currentStatus)
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: OrderStatusUtils.getStatusColor(
                                      status,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(
                                  OrderStatusUtils.formatStatus(status),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
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
                if (widget.order.orderStatus == 'completed' ||
                    widget.order.orderStatus == 'to_receive') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Cannot delete ${OrderStatusUtils.formatStatus(widget.order.orderStatus)} orders',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                _showDeleteConfirmationDialog();
              },
              icon: const Icon(
                Icons.delete_outline,
                size: 16,
                color: Colors.red,
              ),
              label: const Text(
                'Delete',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildOrderSummaryCard() {
    final shippingFee = _controller.getShippingFee();
    final subtotal = _controller.calculateSubtotal(widget.products);
    final grandTotal = _controller.calculateGrandTotal(widget.products);

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
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
              final productName =
                  details['name'] as String? ?? 'Unknown Product';

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
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
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
                                            Icons.image,
                                            color: Colors.grey[400],
                                            size: 20,
                                          ),
                                    ),
                                  )
                                : Icon(
                                    Icons.image,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
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
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
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
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
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
                Divider(color: Colors.grey[300], thickness: 1),
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
                child: const Icon(Icons.timeline, color: Colors.blue, size: 16),
              ),
              const SizedBox(width: 12),
              const Text(
                'Order Timeline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // CHANGE: Use controller to get timeline items
          Column(
            children: _controller.getTimelineItems(widget.order).map((item) =>
                _buildTimelineItem(
                  item.title,
                  item.date,
                  item.icon,
                  item.color,
                  isCompleted: item.isCompleted,
                  isFirst: item.isFirst,
                  isLast: item.isLast,
                ),
            ).toList(),
          ),
        ],
      ),
    );
  }


  // Right Column Cards - Smaller and more compact

  Widget _buildReturnInfoCard() {
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
                child: const Icon(Icons.assignment_return, color: Colors.green, size: 14),
              ),
              const SizedBox(width: 8),
              const Text(
                'Return Details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Return Eligibility
          // Return Eligibility - Enhanced display
          _buildReturnEligibilityInfo(widget.order),

          // Check if there are return requests for this order
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('returnRequests')
                .where('userID', isEqualTo: widget.order.customerId)
                .where('orderID', isEqualTo: widget.order.id)
                .snapshots(),

            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8E6CEF),
                    ),
                  ),
                );
              }

              if (snapshot.data!.docs.isEmpty) {
                // No return requests found - show message
                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No return requests for this order',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Active Return Requests Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Return Requests (${snapshot.data!.docs.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Return Request List
                  ...snapshot.data!.docs.map((doc) {
                    final returnData = doc.data() as Map<String, dynamic>;
                    final returnId = doc.id;
                    final status = returnData['status'] ?? 'Pending';
                    final createdAt = (returnData['createdTime'] as Timestamp?)?.toDate();
                    final reason = returnData['reason'] ?? 'Not specified';

                    return GestureDetector(
                      onTap: () {
                        // Navigate to return request details
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReturnRequestDetailsView(
                              returnRequestId: returnId,
                              userId: widget.order.customerId ?? '',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Return ID and Status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Return #${returnId.substring(0, 6).toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: ReturnStatusUtils.getReturnStatusColor(status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: ReturnStatusUtils.getReturnStatusColor(status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Reason
                            Row(
                              children: [
                                const Icon(Icons.info_outline, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Reason: $reason',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            // Date
                            if (createdAt != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Requested: ${DateFormat('MMM d, y').format(createdAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // View Details Link
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'View Details',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 12,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

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
                child: const Icon(Icons.payment, color: Colors.green, size: 14),
              ),
              const SizedBox(width: 8),
              const Text(
                'Payment',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.order.payment ?? 'Pending',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (shipment?.trackingNumber?.isNotEmpty ?? false) ...[
            _buildInfoRow('Tracking', shipment!.trackingNumber!.toString()),
            const SizedBox(height: 8),
          ],
          if (shipment?.shippedDate != null) ...[
            _buildInfoRow('Shipped', _formatDate(shipment!.shippedDate!)),
          ] else ...[
            Text(
              'Not yet shipped',
              style: TextStyle(fontSize: 15, color: Colors.orange[600]),
            ),
          ],
          const SizedBox(height: 8),
          if (shipment?.fullName?.isNotEmpty ?? false) ...[
            _buildInfoRow('Recipient', shipment!.fullName!),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (shipment?.streetone?.isNotEmpty ?? false) ...[
            _buildInfoRow('Street 1', shipment!.streetone ?? ''),
            const SizedBox(height: 4),
          ],
          if (shipment?.streettwo?.isNotEmpty ?? false) ...[
            _buildInfoRow('Street 2', shipment!.streettwo?? ''),
            const SizedBox(height: 4),
          ],
          if ((shipment?.city?.isNotEmpty ?? false) ||
              (shipment?.state?.isNotEmpty ?? false) ||
              (shipment?.zipCode?.isNotEmpty ?? false)) ...[
            _buildInfoRow(
              'City/State/Zip',
              '${shipment?.city ?? ""}${(shipment?.city?.isNotEmpty ?? false) && (shipment?.state?.isNotEmpty ?? false) ? ", " : ""}${shipment?.state ?? ""} ${shipment?.zipCode ?? ""}'.trim(),
            ),
            const SizedBox(height: 4),
          ],

        ],
      ),
    );
  }

  Future<void> fetchCustomerName() async {
    if (widget.order.customerId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.order.customerId)
          .get();

      if (doc.exists) {
        setState(() {
          customerFullName = doc['fullName'];
        });
      } else {
        setState(() {
          customerFullName = "Unknown";
        });
      }
    }
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
                child: const Icon(Icons.person, color: Colors.purple, size: 14),
              ),
              const SizedBox(width: 8),
              const Text(
                'Customer',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Email', widget.customerNames[widget.order.customerId] ?? 'No Email Available'),
          const SizedBox(height: 8),
          _buildInfoRow('User ID', shortUserId(widget.order.customerId ?? "")),
          const SizedBox(height: 8),
          _buildInfoRow('Full Name', customerFullName ?? "Not found")
        ],
      ),
    );
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
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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



  void _handleStatusChange(String? newStatus) async {
    if (newStatus != null && newStatus != currentStatus) {
      // Check if transition is allowed
      if (!_controller.isTransitionAllowed(currentStatus, newStatus)) {
        _showTransitionError(currentStatus, newStatus);
        return;
      }

      bool proceedWithUpdate = false;

      // Handle specific transitions
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
          await _loadOrderData(); // Re-fetch shipment + payment
        }

      }
    }
  }

  // Update order status with UI feedback
  Future<void> _updateOrderStatus(String newStatus) async {
    try {
      await _controller.updateOrderStatus(
        customerId: widget.order.customerId!,
        orderId: widget.order.id,
        newStatus: newStatus,
      );
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

  // Handle ship to receive transition
  Future<bool> _handleShipToReceive() async {
    final validationResult = _controller.validateShipToReceive(
      order: widget.order,
      shipment: shipment,
    );

    switch (validationResult) {
      case OrderDetailsManagementController.NO_PAYMENT:
        return await _showPaymentWarningDialog();

      case OrderDetailsManagementController.INCOMPLETE_ADDRESS:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Shipping address is incomplete. Please update customer information first.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return false;

      case OrderDetailsManagementController.NO_TRACKING:
        return await _showTrackingNumberDialog();

      case OrderDetailsManagementController.VALIDATION_OK:
        return true;

      default:
        return false;
    }
  }

  // Show payment warning dialog
  Future<bool> _showPaymentWarningDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Not Confirmed'),
        content: const Text(
          'This order does not have a recorded payment method. Are you sure you want to ship it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Proceed Anyway'),
          ),
        ],
      ),
    ) ?? false;
  }

  // Handle receive to completed transition
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
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber[900],
                      ),
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
              await _controller.updateOrderCompletion(
                customerId: widget.order.customerId!,
                orderId: widget.order.id,
              );
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete Order'),
          ),
        ],
      ),
    ) ?? false;
  }

  // Handle order cancellation
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
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red[900],
                        ),
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
                  const SnackBar(
                    content: Text('Please provide a cancellation reason'),
                  ),
                );
                return;
              }
              await _controller.updateOrderCancellation(
                customerId: widget.order.customerId!,
                orderId: widget.order.id,
                cancellationReason: reasonController.text.trim(),
              );
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    ) ?? false;
  }

  // Show tracking number dialog
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
                  const SnackBar(
                    content: Text('Please enter a tracking number'),
                  ),
                );
                return;
              }

              try {
                final success = await _controller.updateTrackingNumber(
                  customerId: widget.order.customerId!,
                  orderId: widget.order.id,
                  trackingNumber: trackingNumberController.text.trim(),
                );

                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Shipment document not found'),
                    ),
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
                    SnackBar(content: Text(e.toString())),
                  );
                  Navigator.pop(context, false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  // Show delete confirmation dialog
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete this order?',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
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
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
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
                        Navigator.pop(context); // Close order details page

                        try {
                          await _controller.deleteOrder(
                            customerId: widget.order.customerId!,
                            orderId: widget.order.id,
                          );
                          await widget.onOrdersReload();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error deleting order: $e')),
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
                      child: const Text(
                        'Delete Order',
                        style: TextStyle(fontSize: 13),
                      ),
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


  // Show transition error
  void _showTransitionError(String from, String to) {
    final errorMessage = _controller.getTransitionErrorMessage(from, to);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
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

  String getReturnEligibilityText(OrdersModel order) {
    if (!order.eligibilityForReturn) {
      return 'Not Eligible';
    }

    if (order.orderStatus.toLowerCase() != 'completed' &&
        order.orderStatus.toLowerCase() != 'delivered') {
      return 'Not Eligible';
    }

    if (order.completedDate != null) {
      final daysSinceCompleted = DateTime.now().difference(order.completedDate!).inDays;
      final daysRemaining = 5 - daysSinceCompleted;

      if (daysRemaining <= 0) {
        return 'Expired';
      } else if (daysRemaining == 1) {
        return 'Expires Today';
      } else {
        return '$daysRemaining days remaining';
      }
    }

    return 'Yes';
  }

  Color getReturnEligibilityColor(OrdersModel order) {
    if (!order.eligibilityForReturn) {
      return Colors.grey;
    }

    if (order.orderStatus.toLowerCase() != 'completed' &&
        order.orderStatus.toLowerCase() != 'delivered') {
      return Colors.grey;
    }

    if (order.completedDate != null) {
      final daysSinceCompleted = DateTime.now().difference(order.completedDate!).inDays;
      final daysRemaining = 5 - daysSinceCompleted;

      if (daysRemaining <= 0) {
        return Colors.red;
      } else if (daysRemaining <= 1) {
        return Colors.orange;
      } else if (daysRemaining <= 2) {
        return Colors.amber;
      } else {
        return Colors.green;
      }
    }

    return Colors.green;
  }

  bool isEligibleForReturn(OrdersModel order) {
    // First check if order status allows returns
    if (order.orderStatus.toLowerCase() != 'completed' &&
        order.orderStatus.toLowerCase() != 'delivered') {
      return false;
    }

    // Check if eligibilityForReturn is already false
    if (!order.eligibilityForReturn) {
      return false;
    }

    // Check if 5 days have passed since completion
    if (order.completedDate != null) {
      final daysSinceCompleted = DateTime.now().difference(order.completedDate!).inDays;
      if (daysSinceCompleted > 5) {
        return false;
      }
    }

    return true;
  }

  Widget _buildReturnEligibilityInfo(OrdersModel order) {
    final eligibilityText = getReturnEligibilityText(order);
    final eligibilityColor = getReturnEligibilityColor(order);
    final isEligible = isEligibleForReturn(order);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Return Eligibility',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: eligibilityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: eligibilityColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEligible ? Icons.check_circle : Icons.cancel,
                size: 14,
                color: eligibilityColor,
              ),
              const SizedBox(width: 4),
              Text(
                eligibilityText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: eligibilityColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
