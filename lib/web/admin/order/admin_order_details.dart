// FILE: order_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:secondsight/view/widgets/dateTime_utils.dart';
import 'package:secondsight/view/widgets/order_status_utils.dart';
import 'package:secondsight/web/admin/product/admin_product.dart';
import 'package:secondsight/web/admin/widget/viewdetails_button.dart';
import '../../../admin_main.dart';
import '../../../model/cancel_model.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../../model/return_request_model.dart';
import '../../../model/shipment_model.dart';
import '../../../model/payment_cards_model.dart';
import '../../../view/returnRefund/return_request_details.dart';
import '../../../view/widgets/product_status_utils.dart';
import '../../../view/widgets/return_status_utils.dart';
import '../../../view/widgets/user_utils.dart';
import '../customer/admin_customer.dart';
import '../customer/admin_customer_details.dart';
import '../returnrefund/admin_return.dart';
import '../returnrefund/admin_return_details.dart';
import '../services/admin_auth_provider.dart';
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
  CancellationModel? cancelData;

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
    _fetchCancellationData();
  }

  Future<void> _loadOrderData() async {
    final data = await _controller.loadOrderData(
      customerId: widget.order.customerId!,
      orderId: widget.order.id,
      payment: widget.order.payment,
    );

    setState(() {
      shipment = data.shipment;
      paymentCard = data.paymentCard;
      isLoading = false;
    });
  }
  Future<void> _fetchCancellationData() async {
    if (widget.order.cancelID != null) {
      final data = await _controller.getCancellationDetails(widget.order.cancelID!);
      setState(() {
        cancelData = data;
      });
    }
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
    final adminProvider = Provider.of<AdminAuthProvider>(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Sidebar
          AdminSidebar(
            currentPage: currentPage,
            onPageChanged: (String page) {
              // Always go back to AdminNavigator with the selected page
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (context) => AdminNavigator(initialPage: page)
                ),
                    (route) => false,
              );
            },
            adminPermissions: adminProvider.permissions,
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
                    _buildCancelInfoCard(),
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
                      DateFormatter.formatDateTime(widget.order.orderDate),
                      // Output: Jul 17, 2025 • 01:06 AM
                    )
                  ],
                ),
              ],
            ),
          ),
          // Delete Button
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
                return _buildNoReturnRequestsMessage();
              }

              return _buildReturnRequestsList(snapshot.data!.docs);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoReturnRequestsMessage() {
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
  Widget _buildReturnRequestsList(List<QueryDocumentSnapshot> docs) {
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
              'Active Return Requests (${docs.length})',
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
        ...docs.map((doc) => _buildReturnRequestItem(doc)).toList(),
      ],
    );
  }

  Widget _buildReturnRequestItem(QueryDocumentSnapshot doc) {
    final returnData = doc.data() as Map<String, dynamic>;
    final returnId = doc.id;
    final status = returnData['status'] ?? 'Pending';
    final createdAt = (returnData['createdTime'] as Timestamp?)?.toDate();
    final reason = returnData['reason'] ?? 'Not specified';

    return Container(
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
                'Return #${ReturnStatusUtils.shortReturnId(returnId)}',
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

          // View Details Link - USING REUSABLE WIDGET
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ViewDetailsLink(
                onTap: () => _handleReturnDetailsNavigation(returnId),
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                arrowSize: 10,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleReturnDetailsNavigation(String returnId) async {
    try {
      // Access return request from the top-level 'returnRequests' collection
      final returnDoc = await FirebaseFirestore.instance
          .collection('returnRequests')
          .doc(returnId)
          .get();

      if (!returnDoc.exists) {
        _showErrorMessage('Return request not found');
        return;
      }

      // Create ReturnRequestModel from the document
      final returnRequest = ReturnRequestModel.fromDocument(returnDoc);

      // Navigate to admin return details page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReturnDetailsPage(
            returnRequest: returnRequest,
            onUpdateReturnStatus: _controller.updateReturnStatus,
            formatDate: _controller.formatReturnDate,
            formatStatus: _controller.formatReturnStatus,
            firestore: FirebaseFirestore.instance,
            getOrderProductDoc: _controller.getOrderProductDoc,
            allReturns: [], // Populate with current returns list if needed
            currentIndex: 0, // Set appropriate index
            selectedFilter: null, // Set appropriate filter if needed
          ),
        ),
      );
    } catch (e) {
      _showErrorMessage('Error loading return details: $e');
    }
  }

// Helper method for error messages
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
          const SizedBox(height: 12),
          _buildInfoRow('Transaction ID', widget.order.payment ?? 'Pending'),

          // Display payment card details if available and valid
          if (widget.order.paymentCard != null && widget.order.paymentCard!.isNotEmpty) ...[
            const SizedBox(height: 8),
            FutureBuilder<Map<String, dynamic>?>(
              future: _controller.fetchPaymentCardDetails(
                customerId: widget.order.customerId!,
                paymentCardId: widget.order.paymentCard!,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildInfoRow('Card', 'Loading...');
                }

                if (snapshot.hasError) {
                  return _buildInfoRow('Card', 'Error loading card', valueColor: Colors.red[600]);
                }

                if (snapshot.hasData && snapshot.data != null) {
                  final cardData = snapshot.data!;
                  return Column(
                    children: [
                      _buildInfoRow(
                        'Card',
                        '•••• •••• •••• ${cardData['lastFour'] ?? '****'}',
                        valueColor: Colors.grey[700],
                      ),
                      if (cardData['brand'] != null) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Type',
                          cardData['brand'].toString().toUpperCase(),
                          valueColor: Colors.grey[600],
                        ),
                      ],
                    ],
                  );
                }

                return _buildInfoRow(
                  'Card',
                  'Details unavailable',
                  valueColor: Colors.grey[500],
                );
              },
            ),
          ] else if (widget.order.payment != null && widget.order.payment != 'Pending') ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              'Card',
              'Not linked',
              valueColor: Colors.grey[500],
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (shipment?.trackingNumber?.isNotEmpty ?? false) ...[
            _buildInfoRow('Tracking', shipment!.trackingNumber!.toString()),
            const SizedBox(height: 8),
          ],
          _buildInfoRow(
            'Shipped',
            shipment?.shippedDate != null
                ? _formatDateTime(shipment!.shippedDate!)
                : 'Not yet shipped',
            valueColor: shipment?.shippedDate != null ? null : Colors.orange[600],
          ),

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
          // Header row with title and view details link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side - Title with icon
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
                    'Customer Details',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),

              // Right side - View Details link
              ViewDetailsLink(onTap: () {
                // Navigate to CustomerDetailsPage
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerDetailsPage(
                      userId: widget.order.customerId ?? "",
                    ),
                  ),
                );
              },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Customer information rows
          _buildInfoRow('User ID', shortUserId(widget.order.customerId ?? "")),
          const SizedBox(height: 8),
          _buildInfoRow('Full Name', customerFullName ?? "Not found"),
          const SizedBox(height: 8),
          _buildInfoRow('Email', widget.customerNames[widget.order.customerId] ?? 'No Email Available'),
        ],
      ),
    );
  }

  Widget _buildCancelInfoCard() {
    if (cancelData == null) {
      return const SizedBox(); // Don't show if no cancellation data
    }

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
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.cancel, color: Colors.red, size: 14),
              ),
              const SizedBox(width: 8),
              const Text(
                'Cancellation Details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Cancelled By', cancelData!.cancelledBy),
          const SizedBox(height: 8),
          _buildInfoRow('Reason', cancelData!.cancelReason),
          if (cancelData!.cancelNote != null && cancelData!.cancelNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Note', cancelData!.cancelNote!),
          ],
          const SizedBox(height: 8),
          _buildInfoRow('Date', DateFormatter.formatDateTime(cancelData!.cancelDate)),
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
        case 'to_ship->cancelled':
        case 'to_receive->cancelled':
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
    final cancelNoteController = TextEditingController();
    String? selectedReason;

    // Predefined cancellation reasons
    final List<String> cancellationReasons = [
      'Customer requested cancellation',
      'Payment issues',
      'Item out of stock',
      'Shipping address issues',
      'Duplicate order',
      'Administrative error',
      'Quality concerns',
      'Other',
    ];

    return await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Cancel Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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

              // Cancellation Reason Dropdown
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(
                    labelText: 'Cancellation Reason *',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                  hint: const Text('Select reason for cancellation'),
                  items: cancellationReasons.map((reason) {
                    return DropdownMenuItem<String>(
                      value: reason,
                      child: Text(
                        reason,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                      // Update the reasonController with the selected value
                      reasonController.text = value ?? '';
                    });
                  },
                  isExpanded: true,
                ),
              ),

              const SizedBox(height: 16),

              // Additional Notes Text Field
              TextField(
                controller: cancelNoteController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  hintText: 'Add any additional details about the cancellation',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),

              const SizedBox(height: 8),
              Text(
                'Please select a reason and optionally provide additional details.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
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
                // Validate that a reason is selected
                if (selectedReason == null || selectedReason!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a cancellation reason'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // If "Other" is selected, make sure there's additional info
                if (selectedReason == 'Other' && cancelNoteController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide additional details when selecting "Other"'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  await _controller.updateOrderCancellation(
                    customerId: widget.order.customerId!,
                    orderId: widget.order.id,
                    cancellationReason: reasonController.text.trim(), // This contains the selected reason
                    cancelNote: cancelNoteController.text.trim().isEmpty
                        ? null
                        : cancelNoteController.text.trim(), // This contains additional notes
                  );
                  Navigator.pop(context, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to cancel order: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cancel Order'),
            ),
          ],
        ),
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

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.black
          ),
        ),
      ],
    );
  }
}
