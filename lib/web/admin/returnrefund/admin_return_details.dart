import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:secondsight/view/widgets/return_status_utils.dart';
import '../../../admin_main.dart';
import '../../../model/order_model.dart';
import '../../../model/return_request_model.dart';

import '../../../model/order_product_model.dart';
import '../customer/admin_customer.dart';
import '../order/admin_order.dart';
import '../product/admin_product.dart';

import '../widget/sidebar.dart';
import '../widget/topbar.dart';
import 'admin_return_controller.dart';

class ReturnDetailsPage extends StatefulWidget {
  final Map<String, dynamic> returnItem;
  final Future<bool> Function(String, String) onUpdateReturnStatus;
  final String Function(Timestamp) formatDate;
  final String Function(String) formatStatus;
  final FirebaseFirestore firestore;
  final Future<DocumentSnapshot?> Function(String, String, String) getOrderProductDoc;

  const ReturnDetailsPage({
    Key? key,
    required this.returnItem,
    required this.onUpdateReturnStatus,
    required this.formatDate,
    required this.formatStatus,
    required this.firestore,
    required this.getOrderProductDoc,
  }) : super(key: key);

  @override
  State<ReturnDetailsPage> createState() => _ReturnDetailsPageState();
}

class _ReturnDetailsPageState extends State<ReturnDetailsPage> {
  late String currentStatus;
  bool isLoading = true;
  String currentPage = 'returns';

  OrdersModel? order;
  OrderProductModel? orderProduct;
  Map<String, dynamic>? productDetails;
  Map<String, dynamic>? customerDetails;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.returnItem['status'] ?? 'submitted';
    _loadReturnData();
  }

  Future<void> _loadReturnData() async {
    try {
      // Load order details
      final orderDoc = await widget.firestore
          .collection('orders')
          .doc(widget.returnItem['orderId'])
          .get();

      if (orderDoc.exists) {
        order = OrdersModel.fromJson(orderDoc.data() as Map<String, dynamic>, orderDoc.id);
      }

      // Load order product details with null safety
      final orderProductDoc = await widget.getOrderProductDoc(
        widget.returnItem['userEmail'],
        widget.returnItem['orderId'],
        widget.returnItem['orderProductId'],
      );

      if (orderProductDoc != null && orderProductDoc.exists) {
        orderProduct = OrderProductModel.fromJson(
            orderProductDoc.data() as Map<String, dynamic>
        );

        // Load product details with null safety
        if (orderProduct!.productID != null) {
          try {
            final productRef = orderProduct!.productID as DocumentReference;
            final productDoc = await productRef.get();
            if (productDoc.exists) {
              productDetails = productDoc.data() as Map<String, dynamic>;
            }
          } catch (e) {
            print('Error loading product details: $e');
            // Handle case where productID is not a DocumentReference
            productDetails = null;
          }
        }
      }

      // Load customer details
      final customerDoc = await widget.firestore
          .collection('customers')
          .doc(widget.returnItem['userEmail'])
          .get();

      if (customerDoc.exists) {
        customerDetails = customerDoc.data() as Map<String, dynamic>;
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading return data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Add this helper method to safely format dates
  String _safeFormatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';

    try {
      if (dateValue is Timestamp) {
        return widget.formatDate(dateValue);
      } else if (dateValue is int) {
        // Handle Unix timestamp in milliseconds
        final timestamp = Timestamp.fromMillisecondsSinceEpoch(dateValue);
        return widget.formatDate(timestamp);
      } else if (dateValue is String) {
        // Try to parse string as timestamp
        final parsed = int.tryParse(dateValue);
        if (parsed != null) {
          final timestamp = Timestamp.fromMillisecondsSinceEpoch(parsed);
          return widget.formatDate(timestamp);
        }
      }
      return 'Invalid Date';
    } catch (e) {
      print('Error formatting date: $e');
      return 'Invalid Date';
    }
  }

  // Update the _buildHeaderSection method to use safe date formatting
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
          // Return ID and Status
          Expanded(
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Return #${widget.returnItem['returnId'] ?? 'Unknown'}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _safeFormatDate(widget.returnItem['date']), // Use safe formatting
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: ReturnStatusUtils.getReturnStatusColor(currentStatus)
                        .withOpacity(0.1),
                    border: Border.all(
                      color: ReturnStatusUtils.getReturnStatusColor(currentStatus),
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButton<String>(
                    value: currentStatus,
                    underline: const SizedBox(),
                    isDense: true,
                    items: ['submitted', 'approved', 'rejected', 'completed', 'cancelled']
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
                              color: ReturnStatusUtils.getReturnStatusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            widget.formatStatus(status),
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
              onPressed: _showDeleteConfirmationDialog,
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

  Future<void> _handleStatusChange(String? newStatus) async {
    if (newStatus != null && newStatus != currentStatus) {
      try {
        final success = await widget.onUpdateReturnStatus(
          widget.returnItem['id'],
          newStatus,
        );

        if (success) {
          setState(() {
            currentStatus = newStatus;
            widget.returnItem['status'] = newStatus;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Return status updated to ${widget.formatStatus(newStatus)}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Return Request'),
          content: const Text(
            'Are you sure you want to delete this return request? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop();

                try {
                  await widget.firestore
                      .collection('returnRequests')
                      .doc(widget.returnItem['id'])
                      .delete();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Return request deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete return request: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
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
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => AdminNavigator()),
                        (route) => false,
                  );
                  break;
                case 'products':
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => ProductManagementPage(),
                    ),
                  );
                  break;
                case 'orders':
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => OrderManagementPage(),
                    ),
                  );
                  break;
                case 'returns':
                  Navigator.of(context).pop();
                  break;
                case 'customers':
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => CustomerManagementPage(),
                    ),
                  );
                  break;
                case 'reports':
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
                const CustomTopBar(
                  title: 'Returns',
                  subtitle: 'Return Details',
                ),
                // Content Area
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
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
          // Header Section
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
                    _buildReturnSummaryCard(),
                    const SizedBox(height: 20),
                    _buildReturnTimeline(),
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
                    _buildOrderInfoCard(),
                    const SizedBox(height: 16),
                    _buildCustomerInfoCard(),
                    const SizedBox(height: 16),
                    _buildPaymentInfoCard(),
                    const SizedBox(height: 16),
                    _buildReasonInfoCard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildReturnSummaryCard() {
    final productName = productDetails?['name'] ?? 'Unknown Product';
    final imageUrl = productDetails?['imageUrl'];
    final quantity = orderProduct?.productQuantity ?? 1;
    final price = orderProduct?.price ?? widget.returnItem['returnPrice'] ?? 0.0;
    final totalPrice = price * quantity;

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
                  Colors.orange.withOpacity(0.1),
                  Colors.orange.withOpacity(0.05),
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
                const Text(
                  'Return Item Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    letterSpacing: 1.2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ReturnStatusUtils.getReturnStatusColor(currentStatus)
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    currentStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ReturnStatusUtils.getReturnStatusColor(currentStatus),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Product Details
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Product Image
                Container(
                  width: 80,
                  height: 80,
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
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.image,
                        color: Colors.grey[400],
                        size: 30,
                      ),
                    ),
                  )
                      : Icon(
                    Icons.image,
                    color: Colors.grey[400],
                    size: 30,
                  ),
                ),
                const SizedBox(width: 20),
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildInfoChip('Order ID', '#${widget.returnItem['shortOrderId']}'),
                          const SizedBox(width: 12),
                          _buildInfoChip('Product ID', widget.returnItem['orderProductId']),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Quantity: ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '$quantity',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            'Unit Price: ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'RM ${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Return Amount
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Return Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RM ${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
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

  Widget _buildReturnTimeline() {
    final timeline = _getReturnTimeline();

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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.timeline, color: Colors.orange, size: 16),
              ),
              const SizedBox(width: 12),
              const Text(
                'Return Timeline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...timeline.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildTimelineItem(
              item['title']!,
              item['date']!,
              item['icon'] as IconData,
              item['color'] as Color,
              isCompleted: item['isCompleted'] as bool,
              isFirst: index == 0,
              isLast: index == timeline.length - 1,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
      String title,
      String date,
      IconData icon,
      Color color, {
        bool isCompleted = false,
        bool isFirst = false,
        bool isLast = false,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            if (!isFirst)
              Container(
                width: 2,
                height: 20,
                color: isCompleted ? color : Colors.grey[300],
              ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted ? color : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 16,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? Colors.black : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderInfoCard() {
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
                child: const Icon(Icons.shopping_bag, color: Colors.blue, size: 14),
              ),
              const SizedBox(width: 8),
              const Text(
                'Order Information',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Order ID', '#${widget.returnItem['shortOrderId']}'),
          const SizedBox(height: 8),
          _buildInfoRow('Order Date', order != null
              ? DateFormat('MMM dd, yyyy').format(order!.orderDate)
              : 'N/A'),
          const SizedBox(height: 8),
          _buildInfoRow('Order Status', order != null
              ? _formatOrderStatus(order!.orderStatus)
              : 'N/A'),
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
                child: const Icon(Icons.person, color: Colors.purple, size: 14),
              ),
              const SizedBox(width: 8),
              const Text(
                'Customer Details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Email', widget.returnItem['userEmail'] ?? 'N/A'),
          if (customerDetails != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Name',
                '${customerDetails!['firstName'] ?? ''} ${customerDetails!['lastName'] ?? ''}'.trim()),
            const SizedBox(height: 8),
            _buildInfoRow('Phone', customerDetails!['phoneNumber'] ?? 'N/A'),
          ],
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
                'Payment Details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Method', 'Credit Card'),
          const SizedBox(height: 8),
          _buildInfoRow('Return Amount',
              'RM ${widget.returnItem['returnPrice'].toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildInfoRow('Refund Status',
              currentStatus == 'completed' ? 'Refunded' : 'Pending'),
        ],
      ),
    );
  }

  Widget _buildReasonInfoCard() {
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.info_outline, color: Colors.orange, size: 14),
              ),
              const SizedBox(width: 8),
              const Text(
                'Return Reason',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              widget.returnItem['reason'] ?? 'No reason provided',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getReturnTimeline() {
    final List<Map<String, dynamic>> timeline = [];

    // Return Submitted
    timeline.add({
      'title': 'Return Submitted',
      'date': _safeFormatDate(widget.returnItem['date']), // Use safe formatting
      'icon': Icons.assignment_return,
      'color': Colors.blue,
      'isCompleted': true,
    });

    // Approved/Rejected
    if (currentStatus == 'approved' || currentStatus == 'rejected' ||
        currentStatus == 'completed' || currentStatus == 'cancelled') {
      timeline.add({
        'title': currentStatus == 'rejected' ? 'Return Rejected' : 'Return Approved',
        'date': currentStatus == 'rejected' ? 'Return request was rejected' : 'Return request approved',
        'icon': currentStatus == 'rejected' ? Icons.cancel : Icons.check_circle,
        'color': currentStatus == 'rejected' ? Colors.red : Colors.green,
        'isCompleted': true,
      });
    } else {
      timeline.add({
        'title': 'Pending Review',
        'date': 'Awaiting approval',
        'icon': Icons.hourglass_empty,
        'color': Colors.orange,
        'isCompleted': false,
      });
    }

    // Processing
    if (currentStatus == 'completed') {
      timeline.add({
        'title': 'Refund Processed',
        'date': 'Refund completed',
        'icon': Icons.paid,
        'color': Colors.green,
        'isCompleted': true,
      });
    } else if (currentStatus == 'approved') {
      timeline.add({
        'title': 'Refund Processing',
        'date': 'Processing refund',
        'icon': Icons.payment,
        'color': Colors.orange,
        'isCompleted': false,
      });
    } else if (currentStatus == 'cancelled') {
      timeline.add({
        'title': 'Return Cancelled',
        'date': 'Return request was cancelled',
        'icon': Icons.cancel,
        'color': Colors.grey,
        'isCompleted': true,
      });
    }

    return timeline;
  }

  String _formatOrderStatus(String status) {
    switch (status) {
      case 'to_ship':
        return 'To Ship';
      case 'to_receive':
        return 'To Receive';
      case 'completed':
        return 'Completed';
      case 'canceled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}