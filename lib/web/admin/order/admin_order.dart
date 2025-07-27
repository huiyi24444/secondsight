// admin_order.dart (Updated with integrated bulk shipment)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../model/order_model.dart';
import '../../../view/widgets/order_status_utils.dart';
import '../widget/topbar.dart';
import 'admin_order_addition.dart';
import 'admin_order_controller.dart';
import 'admin_order_details.dart';

class OrderManagementPage extends StatefulWidget {
  const OrderManagementPage({Key? key}) : super(key: key);

  @override
  State<OrderManagementPage> createState() => _OrderManagementPageState();
}

class _OrderManagementPageState extends State<OrderManagementPage> {
  late OrderManagementController _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = OrderManagementController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showCreateOrderDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CreateOrderDialog(onOrderCreated: _controller.loadOrders);
      },
    );
  }

  Future<void> _processBulkUpdate() async {
    // Validate selections
    if (_controller.selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one order')),
      );
      return;
    }

    // Confirm action
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Update'),
        content: Text('Mark ${_controller.selectedCount} orders as shipped?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _controller.bulkUpdateOrders();

      if (mounted) {
        final message = result['success'] > 0
            ? 'Successfully updated ${result['success']} orders'
            : 'Failed to update orders';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: result['success'] > 0 ? Colors.green : Colors.red,
          ),
        );

        if (result['errors'].isNotEmpty) {
          // Show detailed error dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Update Errors'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: result['errors'].map<Widget>((error) =>
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('• $error'),
                      )
                  ).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<OrderManagementController>(
        builder: (context, controller, child) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            body: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const CustomTopBar(title: 'Order Management'),
                      // Overdue Alert Banner
                      if (controller.overdueOrdersCount > 0)
                        _buildOverdueAlertBanner(controller),
                      // Bulk Mode Banner
                      if (controller.bulkMode)
                        _buildBulkModeBanner(controller),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildHeader(controller),
                              _buildFilterAndSortBar(controller),
                              _buildFilterTabs(controller),
                              const SizedBox(height: 20),
                              _buildOrdersList(controller),
                              _buildPagination(controller),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverdueAlertBanner(OrderManagementController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.orange[50],
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
          const SizedBox(width: 10),
          Text(
            '${controller.overdueOrdersCount} overdue orders need immediate attention',
            style: TextStyle(
              color: Colors.orange[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              controller.setSelectedTab('To Ship');
              controller.toggleOverdueOnly();
            },
            child: Text(
              'View Overdue Orders',
              style: TextStyle(
                color: Colors.orange[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkModeBanner(OrderManagementController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.blue[50],
      child: Row(
        children: [
          Icon(Icons.checklist_rtl, color: Colors.blue[700], size: 20),
          const SizedBox(width: 10),
          Text(
            'Bulk Update Mode - ${controller.selectedCount} orders selected',
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // Select All Checkbox (only for "To Ship" tab)
          if (controller.selectedTab == 'To Ship') ...[
            Checkbox(
              value: controller.allToShipSelected,
              onChanged: (_) => controller.toggleSelectAll(),
            ),
            Text(
              'Select All',
              style: TextStyle(color: Colors.blue[700]),
            ),
            const SizedBox(width: 16),
          ],
          TextButton.icon(
            onPressed: _isProcessing ? null : _processBulkUpdate,
            icon: _isProcessing
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
              ),
            )
                : Icon(Icons.local_shipping, color: Colors.blue[700]),
            label: Text(
              _isProcessing ? 'Processing...' : 'Mark as Shipped',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(OrderManagementController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller.searchController,
              decoration: InputDecoration(
                hintText: 'Search order or customer...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Bulk Update Toggle Button
          ElevatedButton.icon(
            onPressed: controller.toggleBulkMode,
            icon: Icon(controller.bulkMode ? Icons.close : Icons.checklist_rtl),
            label: Text(controller.bulkMode ? 'Exit Bulk Mode' : 'Bulk Update'),
            style: ElevatedButton.styleFrom(
              backgroundColor: controller.bulkMode ? Colors.grey : Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _showCreateOrderDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSortBar(OrderManagementController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Overdue Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: controller.showOverdueOnly ? Colors.orange[100] : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: controller.showOverdueOnly
                  ? Border.all(color: Colors.orange[300]!)
                  : null,
            ),
            child: InkWell(
              onTap: controller.toggleOverdueOnly,
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  Icon(
                    controller.showOverdueOnly
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 16,
                    color: controller.showOverdueOnly
                        ? Colors.orange[700]
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Show Overdue Only',
                    style: TextStyle(
                      color: controller.showOverdueOnly
                          ? Colors.orange[700]
                          : Colors.grey[700],
                      fontWeight: controller.showOverdueOnly
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Sort Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<SortOption>(
              value: controller.currentSort,
              underline: const SizedBox(),
              isDense: true,
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
              onChanged: (value) {
                if (value != null) controller.setSortOption(value);
              },
              items: const [
                DropdownMenuItem(
                  value: SortOption.overdueFirst,
                  child: Row(
                    children: [
                      Icon(Icons.priority_high, size: 16, color: Colors.orange),
                      SizedBox(width: 6),
                      Text('Overdue First'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: SortOption.dateNewest,
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Text('Newest First'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: SortOption.dateOldest,
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Text('Oldest First'),
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

  Widget _buildFilterTabs(OrderManagementController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(top: 10),
      child: Row(
        children: [
          _buildFilterTab('All', controller.selectedTab == 'All', controller),
          const SizedBox(width: 20),
          _buildFilterTab('To Ship', controller.selectedTab == 'To Ship', controller,
              showBadge: controller.overdueOrdersCount > 0),
          const SizedBox(width: 20),
          _buildFilterTab('To Receive', controller.selectedTab == 'To Receive', controller),
          const SizedBox(width: 20),
          _buildFilterTab('Completed', controller.selectedTab == 'Completed', controller),
          const SizedBox(width: 20),
          _buildFilterTab('Cancelled', controller.selectedTab == 'Cancelled', controller),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String title, bool isActive, OrderManagementController controller, {bool showBadge = false}) {
    return InkWell(
      onTap: () => controller.setSelectedTab(title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF7C3AED) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isActive ? const Color(0xFF7C3AED) : Colors.grey[600],
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (showBadge && title == 'To Ship') ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${controller.overdueOrdersCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(OrderManagementController controller) {
    return Expanded(
      child: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : controller.filteredOrders.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              controller.showOverdueOnly
                  ? 'No overdue orders found'
                  : 'No orders found',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        child: Column(
          children: controller.currentOrders.map((order) {
            return _buildOrderCard(order, controller);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrdersModel order, OrderManagementController controller) {
    final products = controller.orderProducts[order.id] ?? [];
    final isOverdue = controller.isOrderOverdue(order);
    final daysOverdue = controller.getDaysOverdue(order);
    final isSelected = controller.selectedOrders[order.id] ?? false;
    final canSelect = controller.bulkMode && order.orderStatus.toLowerCase() == 'to_ship';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.blue[400]! : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? Colors.blue[50] : Colors.white,
      ),
      child: InkWell(
        onTap: canSelect ? () => controller.toggleOrderSelection(order.id) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Checkbox (only shown in bulk mode for "to_ship" orders)
              if (controller.bulkMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: canSelect ? (_) => controller.toggleOrderSelection(order.id) : null,
                ),
                const SizedBox(width: 12),
              ],
              // Overdue indicator
              if (isOverdue && !controller.bulkMode) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.priority_high,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${order.shortOrderId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (isOverdue) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${daysOverdue}d overdue',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${products.length} product${products.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  controller.formatDate(order.orderDate),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  controller.customerNames[order.customerId] ?? 'Unknown',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'RM ${order.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              // Tracking Number Input (shown in bulk mode for selected "to_ship" orders)
              if (controller.bulkMode && canSelect && isSelected) ...[
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextFormField(
                      controller: controller.getTrackingController(order.id),
                      decoration: InputDecoration(
                        hintText: 'Enter tracking number',
                        hintStyle: TextStyle(fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.blue[400]!),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  flex: controller.bulkMode ? 3 : 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: OrderStatusUtils.getStatusColor(order.orderStatus).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      OrderStatusUtils.formatStatus(order.orderStatus),
                      style: TextStyle(
                        color: OrderStatusUtils.getStatusColor(order.orderStatus),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              // Action buttons (hidden in bulk mode)
              if (!controller.bulkMode) ...[
                IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailsPage(
                        order: order,
                        products: controller.orderProducts[order.id] ?? [],
                        productDetails: controller.productDetails,
                        customerNames: controller.customerNames,
                        firestore: FirebaseFirestore.instance,
                        onOrdersReload: controller.loadOrders,
                      ),
                    ),
                  ),
                  tooltip: 'View Details',
                ),
                _buildOrderActions(order, controller),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderActions(OrdersModel order, OrderManagementController controller) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'delete') {
          _showDeleteConfirmation(order, controller);
        } else {
          controller.updateOrderStatus(order, value);
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete Order', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildPagination(OrderManagementController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${controller.startIndex + 1} to ${controller.endIndex > controller.filteredOrders.length ? controller.filteredOrders.length : controller.endIndex} of ${controller.filteredOrders.length} items',
          ),
          Row(
            children: [
              IconButton(
                onPressed: controller.currentPage > 1
                    ? () => controller.setCurrentPage(controller.currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              ...List.generate(
                controller.totalPages > 5 ? 5 : controller.totalPages,
                    (index) {
                  final pageNum = index + 1;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => controller.setCurrentPage(pageNum),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: controller.currentPage == pageNum
                            ? const Color(0xFF7C3AED)
                            : Colors.grey[300],
                        foregroundColor: controller.currentPage == pageNum
                            ? Colors.white
                            : Colors.black,
                        minimumSize: const Size(40, 40),
                      ),
                      child: Text('$pageNum'),
                    ),
                  );
                },
              ),
              IconButton(
                onPressed: controller.currentPage < controller.totalPages
                    ? () => controller.setCurrentPage(controller.currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(OrdersModel order, OrderManagementController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Order'),
          content: Text('Are you sure you want to delete order #${order.shortOrderId}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                controller.deleteOrder(order);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}