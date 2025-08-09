import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:secondsight/view/widgets/product_status_utils.dart';
import 'package:secondsight/view/widgets/return_status_utils.dart';
import 'package:secondsight/view/widgets/user_utils.dart';
import '../../../admin_main.dart';
import '../../../model/order_model.dart';
import '../../../model/refund_model.dart';
import '../../../model/return_request_model.dart';

import '../../../model/order_product_model.dart';
import '../../../view/widgets/dateTime_utils.dart';
import '../../../view/widgets/order_status_utils.dart';
import '../customer/admin_customer.dart';
import '../customer/admin_customer_details.dart';
import '../order/admin_order.dart';
import '../order/admin_order_details.dart';
import '../product/admin_product.dart';

import '../services/admin_auth_provider.dart';
import '../widget/sidebar.dart';
import '../widget/topbar.dart';
import '../widget/viewdetails_button.dart';
import 'admin_return_controller.dart';
import 'admin_return_details_controller.dart';
import 'admin_return_nav.dart';

class ReturnDetailsPage extends StatefulWidget {
  final ReturnRequestModel returnRequest;
  final Future<bool> Function(String, String) onUpdateReturnStatus;
  final String Function(Timestamp) formatDate;
  final String Function(String) formatStatus;
  final FirebaseFirestore firestore;
  final Future<DocumentSnapshot?> Function(String, String, String) getOrderProductDoc;

  final List<Map<String, dynamic>> allReturns;
  final int currentIndex;
  final String? selectedFilter;

  const ReturnDetailsPage({
    Key? key,
    required this.returnRequest,
    required this.onUpdateReturnStatus,
    required this.formatDate,
    required this.formatStatus,
    required this.firestore,
    required this.getOrderProductDoc,

    required this.allReturns,
    required this.currentIndex,
    this.selectedFilter,
  }) : super(key: key);

  @override
  State<ReturnDetailsPage> createState() => _ReturnDetailsPageState();
}

class _ReturnDetailsPageState extends State<ReturnDetailsPage> {
  late String currentStatus;
  bool isLoading = true;
  String currentPage = 'returns';
  late AdminReturnDetailsController _controller;

  late ReturnNavigationService _navigationService;
  late FocusNode _focusNode;

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

    currentStatus = widget.returnRequest.returnStatus == 'submitted'
        ? 'submitted'
        : widget.returnRequest.returnStatus;

    _controller = AdminReturnDetailsController(
      returnRequest: widget.returnRequest,
      firestore: widget.firestore,
      getOrderProductDoc: widget.getOrderProductDoc,
    );

    _navigationService = ReturnNavigationService(
      allReturns: widget.allReturns,
      currentIndex: widget.currentIndex,
      selectedFilter: widget.selectedFilter,
      context: context,
      onUpdateReturnStatus: widget.onUpdateReturnStatus,
      formatDate: widget.formatDate,
      formatStatus: widget.formatStatus,
      firestore: widget.firestore,
      getOrderProductDoc: widget.getOrderProductDoc,
    );

    _focusNode = FocusNode();

    // ✅ ADD: Call initialize() instead of loadReturnData()
    _controller.initialize();

    // Request focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    // ✅ ADD THIS
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
        ),
        child: Row(
          children: [
            // Left side - Return info and status
            Expanded(
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Return #${ReturnStatusUtils.shortReturnId(widget.returnRequest.id)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormatter.formatDateTime(widget.returnRequest.returnDate?.toDate()),
                        // Output: Jul 17, 2025 • 01:06 AM
                      )
                    ],
                  ),


                ],
              ),
            ),

            // Right side - Navigation buttons
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                      color: ReturnStatusUtils.getReturnStatusColor(currentStatus).withOpacity(0.1),
                      border: Border.all(color: ReturnStatusUtils.getReturnStatusColor(currentStatus)),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                  ),
                  child: DropdownButton<String>(
                    value: currentStatus,
                    underline: const SizedBox(),
                    isDense: true,
                    items: [
                      'pending_approval',
                      'approved',
                      'rejected',
                      'refunded',
                      'not_refunded',
                      'cancelled',
                      'pending_inspection',
                      'completed_inspection',
                    ].map((status) {
                      return DropdownMenuItem(
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
                              ReturnStatusUtils.getReturnStatusText(status),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _handleStatusChange,
                  ),

                ),
                const SizedBox(width: 20),
                // Navigation counter/indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.currentIndex + 1} of ${widget.allReturns.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Previous button
                IconButton(
                  onPressed: widget.currentIndex > 0 ? _navigationService.navigateToPrevious : null,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous (← or P)',
                  iconSize: 28,
                  style: IconButton.styleFrom(
                    backgroundColor: widget.currentIndex > 0 ? Colors.grey[100] : Colors.grey[50],
                    foregroundColor: widget.currentIndex > 0 ? Colors.black : Colors.grey[400],
                    padding: const EdgeInsets.all(8),
                  ),
                ),

                // Next button
                IconButton(
                  onPressed: widget.currentIndex < widget.allReturns.length - 1 ? _navigationService.navigateToNext : null,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next (→ or N)',
                  iconSize: 28,
                  style: IconButton.styleFrom(
                    backgroundColor: widget.currentIndex < widget.allReturns.length - 1 ? Colors.grey[100] : Colors.grey[50],
                    foregroundColor: widget.currentIndex < widget.allReturns.length - 1 ? Colors.black : Colors.grey[400],
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ],
        )
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

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminAuthProvider>(context);
    return ChangeNotifierProvider.value(
      value: _controller,
     child: Focus(
       focusNode: _focusNode,
       onKeyEvent: (node, event) => _navigationService.handleKeyEvent(event, currentStatus, _handleStatusChange)
           ? KeyEventResult.handled
           : KeyEventResult.ignored,
       child: Scaffold(
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
               }, adminPermissions: adminProvider.permissions,
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
                     child: Consumer<AdminReturnDetailsController>(
                       builder: (context, controller, child) {
                         return controller.isLoading
                             ? const Center(child: CircularProgressIndicator())
                             : SingleChildScrollView(
                           padding: const EdgeInsets.all(12.0),
                           child: _buildBody(controller),
                         );
                       },
                     ),
                   ),
                 ],
               ),
             ),
           ],
         ),
       ),
     ),
    );
  }

  Widget _buildBody(AdminReturnDetailsController controller) {
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
                    _buildReturnSummaryCard(controller),
                    if (widget.returnRequest.returnImages.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildImagesCard(),
                    ],
                    const SizedBox(height: 20),
                    _buildReturnTimeline(controller),
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
                    _buildReasonInfoCard(),
                    const SizedBox(height: 16),
                    _buildOrderInfoCard(controller),
                    const SizedBox(height: 16),
                    _buildCustomerInfoCard(controller),
                    const SizedBox(height: 16),
                    _buildPaymentInfoCard(controller),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReturnSummaryCard(AdminReturnDetailsController controller) {
    final productName = widget.returnRequest.productName;
    final imageUrl = controller.getCleanImageUrl();
    final quantity = widget.returnRequest.returnQuantity;
    final price = widget.returnRequest.returnPrice;
    final totalPrice = controller.getTotalReturnPrice();

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
                    ReturnStatusUtils.getReturnStatusText(currentStatus),
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
                    'PRODUCT ID',
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
                    '#${controller.getShortOrderId()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '#${controller.getShortOrderId()}',
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
                    ProductStatusUtils.shortProductId(widget.returnRequest.productID),
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
        ],
      ),
    );
  }

  Widget _buildReturnTimeline(AdminReturnDetailsController controller) {
    final timeline = controller.getReturnTimeline();

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
              _formatDate(item['date'] as Timestamp),
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

  Widget _buildOrderInfoCard(AdminReturnDetailsController controller) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side - Title with icon
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
                    'Order Details',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),

              // Right side - View Details link
              if (controller.order != null)
                ViewDetailsLink(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailsPage(
                          order: controller.order!,
                          products: [], // You might need to load products separately
                          productDetails: {},
                          customerNames: {},
                          firestore: FirebaseFirestore.instance,
                          onOrdersReload: () async {},
                        ),
                      ),
                    );
                  },
                  fontSize: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  arrowSize: 10,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Display order information
          _buildInfoRow('Order ID', controller.getShortOrderId()),
          if (controller.order != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Order Status', OrderStatusUtils.getStatusDisplayText(controller.order!.orderStatus)),
            const SizedBox(height: 8),
            _buildInfoRow('Order Date', DateFormatter.formatDateTime(controller.order!.orderDate)),
            const SizedBox(height: 8),
            _buildInfoRow('Total Amount', 'RM ${controller.order!.totalAmount.toStringAsFixed(2)}'),
          ] else ...[
            const SizedBox(height: 8),
            _buildInfoRow('Order Status', 'Loading...'),
            const SizedBox(height: 8),
            _buildInfoRow('Order Date', 'Loading...'),
          ],
        ],
      ),
    );
  }


  Widget _buildCustomerInfoCard(AdminReturnDetailsController controller) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

              ViewDetailsLink(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomerDetailsPage(
                        userId: widget.returnRequest.userID?? "",
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('User ID', shortUserId(widget.returnRequest.userID)),
          const SizedBox(height: 8),
          _buildInfoRow('Full Name', controller.getCustomerName()),
          const SizedBox(height: 8),
          _buildInfoRow('Phone', controller.getCustomerPhone()),
          if (controller.customerDetails != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Email', controller.customerDetails!['email'] ?? 'N/A'),
          ],
        ],
      ),
    );
  }


  Widget _buildPaymentInfoCard(AdminReturnDetailsController controller) {
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
                child: const Icon(Icons.account_balance_wallet, color: Colors.green, size: 14),
              ),
              const SizedBox(width: 8),
              const Text(
                'Refund Details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Check if refundID exists
          if (widget.returnRequest.refundID != null && widget.returnRequest.refundID!.isNotEmpty) ...[
            // Show refund details using FutureBuilder
            FutureBuilder<RefundModel?>(
              future: controller.loadRefundDetails(widget.returnRequest.refundID),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Column(
                    children: [
                      _buildInfoRow('Refund Status', 'Loading...'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Refund Amount', 'Loading...'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Refund Method', 'Loading...'),
                    ],
                  );
                }

                if (snapshot.hasError) {
                  return Column(
                    children: [
                      _buildInfoRow('Refund Status', 'Error loading', valueColor: Colors.red[600]),
                      const SizedBox(height: 8),
                      _buildInfoRow('Refund Amount', 'RM ${controller.getTotalReturnPrice().toStringAsFixed(2)}'),
                    ],
                  );
                }

                if (snapshot.hasData && snapshot.data != null) {
                  final refund = snapshot.data!;
                  return Column(
                    children: [
                      _buildInfoRow('Refund Status', 'Completed', valueColor: Colors.green[600]),
                      const SizedBox(height: 8),
                      _buildInfoRow('Refund Amount', 'RM ${refund.refundAmount.toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Refund Method', refund.refundMethod),
                      const SizedBox(height: 8),
                      _buildInfoRow('Refund Date', DateFormatter.formatDateTime(refund.refundDate)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Transaction ID', refund.transactionId),
                      const SizedBox(height: 8),
                      _buildInfoRow('Refund Type', controller.formatRefundType(refund.refundType)),
                    ],
                  );
                }

                // No refund data found
                return Column(
                  children: [
                    _buildInfoRow('Refund Status', 'Not Found', valueColor: Colors.red[600]),
                    const SizedBox(height: 8),
                    _buildInfoRow('Expected Amount', 'RM ${controller.getTotalReturnPrice().toStringAsFixed(2)}'),
                  ],
                );
              },
            ),
          ] else ...[
            // No refundID - show pending refund info
            _buildInfoRow('Refund Status', 'Pending', valueColor: Colors.orange[600]),
            const SizedBox(height: 8),
            _buildInfoRow('Expected Amount', 'RM ${controller.getTotalReturnPrice().toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildInfoRow('Refund Method', 'To be determined'),
            const SizedBox(height: 12),

            // Info box for pending refund
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Refund will be processed once return is approved',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              crossAxisCount: 4, // More columns = smaller images
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1, // Adjust if needed to change height/width ratio
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
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }
}