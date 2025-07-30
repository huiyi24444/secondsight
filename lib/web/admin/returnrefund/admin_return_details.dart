import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:secondsight/view/widgets/return_status_utils.dart';
import '../../../admin_main.dart';
import '../../../model/order_model.dart';
import '../../../model/return_request_model.dart';

import '../../../model/order_product_model.dart';
import '../../../view/widgets/order_status_utils.dart';
import '../customer/admin_customer.dart';
import '../order/admin_order.dart';
import '../product/admin_product.dart';

import '../widget/sidebar.dart';
import '../widget/topbar.dart';
import 'admin_return_controller.dart';

class ReturnDetailsPage extends StatefulWidget {
  final ReturnRequestModel returnRequest;
  final Future<bool> Function(String, String) onUpdateReturnStatus;
  final String Function(Timestamp) formatDate;
  final String Function(String) formatStatus;
  final FirebaseFirestore firestore;
  final Future<DocumentSnapshot?> Function(String, String, String) getOrderProductDoc;

  const ReturnDetailsPage({
    Key? key,
    required this.returnRequest,
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
    currentStatus = widget.returnRequest.returnStatus == 'submitted'
        ? 'submitted'
        : widget.returnRequest.returnStatus;
    print('=== initState called ===');
    print('Return Request Data:');
    print('- ID: ${widget.returnRequest.id}');
    print('- OrderID: ${widget.returnRequest.orderID}');
    print('- UserID: ${widget.returnRequest.userID}');
    print('- ProductName: ${widget.returnRequest.productName}');

    currentStatus = widget.returnRequest.returnStatus == 'submitted'
        ? 'submitted'
        : widget.returnRequest.returnStatus;
    print('- Current Status: $currentStatus');
    _loadReturnData();
  }

  Future<void> _loadReturnData() async {
    print('=== _loadReturnData STARTED ===');

    try {
      final orderID = widget.returnRequest.orderID;
      final userID = widget.returnRequest.userID;
      final orderProductID = widget.returnRequest.orderProductID;

      print('OrderID: "$orderID"');
      print('UserID: "$userID"');
      print('OrderProductID: "$orderProductID"');
      print('Return Request ID: "${widget.returnRequest.id}"');
      print('Product Name: "${widget.returnRequest.productName}"');
      print('Product Image URL: "${widget.returnRequest.productImageUrl}"');

      // Only load order details if orderID is not empty
      if (orderID != null && orderID.isNotEmpty && userID != null && userID.isNotEmpty) {
        print('Loading order details for orderID: $orderID, userID: $userID');
        try {
          final orderDoc = await widget.firestore
              .collection('users')        // ← CORRECT PATH
              .doc(userID)               // ← User document
              .collection('order')       // ← User's orders subcollection
              .doc(orderID)             // ← Specific order
              .get();

          if (orderDoc.exists) {
            print('Order document found');
            order = OrdersModel.fromJson(orderDoc.data() as Map<String, dynamic>, orderDoc.id);
            print('Order loaded - Date: ${order!.orderDate}, Status: ${order!.orderStatus}');
          } else {
            print('Order document not found for userID: $userID, orderID: $orderID');
          }
        } catch (e) {
          print('Error loading order: $e');
        }
      } else {
        print('Order ID or User ID is empty - OrderID: "$orderID", UserID: "$userID"');
      }

      // Only load order product details if all required IDs are available
      if (userID != null && userID.isNotEmpty &&
          orderID != null && orderID.isNotEmpty &&
          orderProductID != null && orderProductID.isNotEmpty) {

        print('Loading order product details...');
        try {
          final orderProductDoc = await widget.getOrderProductDoc(
            userID,
            orderID,
            orderProductID,
          );

          if (orderProductDoc != null && orderProductDoc.exists) {
            print('Order product document found');
            orderProduct = OrderProductModel.fromJson(
                orderProductDoc.data() as Map<String, dynamic>
            );

            // Load product details with null safety
            if (orderProduct!.productID != null) {
              try {
                print('Loading product details...');
                final productRef = orderProduct!.productID as DocumentReference;
                final productDoc = await productRef.get();
                if (productDoc.exists) {
                  print('Product document found');
                  productDetails = productDoc.data() as Map<String, dynamic>;
                } else {
                  print('Product document not found');
                }
              } catch (e) {
                print('Error loading product details: $e');
                productDetails = null;
              }
            }
          } else {
            print('Order product document not found');
          }
        } catch (e) {
          print('Error loading order product: $e');
        }
      } else {
        print('Missing required IDs for order product fetch');
        print('UserID valid: ${userID != null && userID.isNotEmpty}');
        print('OrderID valid: ${orderID != null && orderID.isNotEmpty}');
        print('OrderProductID valid: ${orderProductID != null && orderProductID.isNotEmpty}');
      }

      // Only load customer details if userID is not empty
      if (userID != null && userID.isNotEmpty) {
        print('Loading customer details for userID: $userID');
        try {
          final customerDoc = await widget.firestore
              .collection('customers')
              .doc(userID)
              .get();

          if (customerDoc.exists) {
            print('Customer document found');
            customerDetails = customerDoc.data() as Map<String, dynamic>;
          } else {
            print('Customer document not found for userID: $userID');
          }
        } catch (e) {
          print('Error loading customer: $e');
        }
      } else {
        print('User ID is empty, skipping customer fetch');
      }

      print('=== Data loading completed ===');
      print('Order loaded: ${order != null}');
      print('Order product loaded: ${orderProduct != null}');
      print('Product details loaded: ${productDetails != null}');
      print('Customer details loaded: ${customerDetails != null}');

      setState(() {
        isLoading = false;
      });

      print('=== _loadReturnData COMPLETED ===');
    } catch (e) {
      print('=== ERROR in _loadReturnData: $e ===');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Helper method to format dates
  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  Widget _buildHeaderSection() {
    return Container(
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
        items: ['pending', 'submitted', 'approved', 'rejected', 'completed', 'cancelled'] // Added 'submitted'
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
    );

  }

  Future<void> _handleStatusChange(String? newStatus) async {
    if (newStatus != null && newStatus != currentStatus) {
      try {
        final success = await widget.onUpdateReturnStatus(
          widget.returnRequest.id,
          newStatus,
        );

        if (success) {
          setState(() {
            currentStatus = newStatus;
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
                      .doc(widget.returnRequest.id)
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
                    if (widget.returnRequest.returnImages.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildImagesCard(),
                    ],
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
    print('Product Name: ${widget.returnRequest.productName}');
    print('Raw Image URL: ${widget.returnRequest.productImageUrl}');

    final productName = widget.returnRequest.productName;
    // Clean the URL - remove any potential whitespace or hidden characters
    final imageUrl = widget.returnRequest.productImageUrl.trim().replaceAll('\n', '').replaceAll('\r', '');
    print('Cleaned Image URL: $imageUrl');
    print('Image URL Length: ${imageUrl.length}');
    print('Image URL isEmpty: ${imageUrl.isEmpty}');

    final quantity = widget.returnRequest.returnQuantity;
    final price = widget.returnRequest.returnPrice;
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Return Item',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
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

          // Table Header
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
                    'ORDER ID',
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

          // Product Item Row
          Container(
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print('Image loading error: $error');
                              // Fallback to a simple colored container
                              return Container(
                                color: Colors.orange[100],
                                child: Icon(
                                  Icons.shopping_bag,
                                  color: Colors.orange[300],
                                  size: 24,
                                ),
                              );
                            },
                          )
                              : Container(
                            color: Colors.grey[100],
                            child: Icon(
                              Icons.image,
                              color: Colors.grey[400],
                              size: 24,
                            ),
                          ),
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
                // Order ID
                Expanded(
                  flex: 3,
                  child: Text(
                    '#${widget.returnRequest.orderID.length > 8 ? widget.returnRequest.orderID.substring(0, 8) : widget.returnRequest.orderID}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                // Quantity
                Expanded(
                  flex: 2,
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                // Unit Price
                Expanded(
                  flex: 2,
                  child: Text(
                    'RM ${price.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ),
                // Total Price
                Expanded(
                  flex: 2,
                  child: Text(
                    'RM ${totalPrice.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Summary Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Product ID info row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Product ID',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    Text(
                      widget.returnRequest.orderProductID,
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

                // Return Amount Total
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(0.1),
                        Colors.orange.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.2),
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
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet,
                              color: Colors.orange,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'RETURN AMOUNT',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'RM ${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
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
          _buildInfoRow('Order ID', '#${widget.returnRequest.orderID.length > 8 ? widget.returnRequest.orderID.substring(0, 8) : widget.returnRequest.orderID}'),
          const SizedBox(height: 8),
          _buildInfoRow('Order Date', order != null
              ? DateFormat('MMM dd, yyyy').format(order!.orderDate)
              : 'N/A'),
          const SizedBox(height: 8),
          _buildInfoRow('Order Status', order != null
              ? OrderStatusUtils.getStatusDisplayText(order!.orderStatus)
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
          _buildInfoRow('User ID', widget.returnRequest.userID),
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
              'RM ${widget.returnRequest.returnPrice.toStringAsFixed(2)}'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.returnRequest.returnReason,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.returnRequest.returnComment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Comment: ${widget.returnRequest.returnComment}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ],
                if (widget.returnRequest.rejectReason != null &&
                    widget.returnRequest.rejectReason!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.cancel, color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Rejection Reason: ${widget.returnRequest.rejectReason}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesCard() {
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
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.image, color: Colors.indigo, size: 14),
              ),
              const SizedBox(width: 8),
              const Text(
                'Return Images',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: widget.returnRequest.returnImages.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () {
                  _showImageDialog(widget.returnRequest.returnImages[index]);
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.returnRequest.returnImages[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.grey[400],
                      size: 48,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
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

  List<Map<String, dynamic>> _getReturnTimeline() {
    final List<Map<String, dynamic>> timeline = [];

    // Always show pending as the first step
    timeline.add({
      'title': 'Return Requested',
      'date': widget.returnRequest.pendingDate != null
          ? _formatDate(widget.returnRequest.pendingDate!)
          : _formatDate(widget.returnRequest.returnDate),
      'icon': Icons.refresh,
      'color': Colors.blue,
      'isCompleted': true,
    });

    // Add approved step if applicable
    if (widget.returnRequest.approvedDate != null) {
      timeline.add({
        'title': 'Return Approved',
        'date': _formatDate(widget.returnRequest.approvedDate!),
        'icon': Icons.check_circle,
        'color': Colors.green,
        'isCompleted': true,
      });
    }

    // Add rejected step if applicable
    if (widget.returnRequest.rejectedDate != null) {
      timeline.add({
        'title': 'Return Rejected',
        'date': _formatDate(widget.returnRequest.rejectedDate!),
        'icon': Icons.cancel,
        'color': Colors.red,
        'isCompleted': true,
      });
    }

    // Add pending inspection step if applicable
    if (widget.returnRequest.pendinginspectionDate != null) {
      timeline.add({
        'title': 'Pending Inspection',
        'date': _formatDate(widget.returnRequest.pendinginspectionDate!),
        'icon': Icons.search,
        'color': Colors.orange,
        'isCompleted': true,
      });
    }

    // Add completed inspection step if applicable
    if (widget.returnRequest.completedinsepectionDate != null) {
      timeline.add({
        'title': 'Inspection Completed',
        'date': _formatDate(widget.returnRequest.completedinsepectionDate!),
        'icon': Icons.verified,
        'color': Colors.teal,
        'isCompleted': true,
      });
    }

    // Add completed step if applicable
    if (widget.returnRequest.completedDate != null) {
      timeline.add({
        'title': 'Return Completed',
        'date': _formatDate(widget.returnRequest.completedDate!),
        'icon': Icons.done_all,
        'color': Colors.green,
        'isCompleted': true,
      });
    }

    // Add cancelled step if applicable
    if (widget.returnRequest.cancelledDate != null) {
      timeline.add({
        'title': 'Return Cancelled',
        'date': _formatDate(widget.returnRequest.cancelledDate!),
        'icon': Icons.block,
        'color': Colors.grey,
        'isCompleted': true,
      });
    }

    // Add future steps based on current status
    if (currentStatus == 'pending') {
      timeline.add({
        'title': 'Awaiting Approval',
        'date': 'Pending',
        'icon': Icons.hourglass_empty,
        'color': Colors.grey,
        'isCompleted': false,
      });
    } else if (currentStatus == 'approved' && widget.returnRequest.completedDate == null) {
      timeline.add({
        'title': 'Processing Refund',
        'date': 'In Progress',
        'icon': Icons.payment,
        'color': Colors.orange,
        'isCompleted': false,
      });
    }

    return timeline;
  }
}