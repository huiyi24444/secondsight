// lib/view/admin/order_management_view.dart

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

  Widget _buildHeader(OrderManagementController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller.searchController,
              decoration: InputDecoration(
                hintText: 'Search order...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 20),
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

  Widget _buildFilterTabs(OrderManagementController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildFilterTab('All', controller.selectedTab == 'All', controller),
          const SizedBox(width: 20),
          _buildFilterTab('To Ship', controller.selectedTab == 'To Ship', controller),
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

  Widget _buildFilterTab(String title, bool isActive, OrderManagementController controller) {
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
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFF7C3AED) : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersList(OrderManagementController controller) {
    return Expanded(
      child: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
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
    final isExpanded = controller.isOrderExpanded(order.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Main order row
          InkWell(
            onTap: () => controller.toggleOrderExpansion(order.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${order.shortOrderId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
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
                  Expanded(
                    flex: 1,
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
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined),
                    onPressed: () => OrderDetailsDialog.show(
                      context,
                      order: order,
                      products: controller.orderProducts[order.id] ?? [],
                      productDetails: controller.productDetails,
                      customerNames: controller.customerNames,
                      firestore: FirebaseFirestore.instance,
                      onOrdersReload: controller.loadOrders,
                    ),
                    tooltip: 'View Details',
                  ),
                  _buildOrderActions(order, controller),
                ],
              ),
            ),
          ),
          // Expandable products section
          if (isExpanded) _buildExpandedProducts(order, controller),
        ],
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
        const PopupMenuItem(value: 'pending', child: Text('Mark as Pending')),
        const PopupMenuItem(value: 'processing', child: Text('Mark as Processing')),
        const PopupMenuItem(value: 'delivered', child: Text('Mark as Delivered')),
        const PopupMenuItem(value: 'cancelled', child: Text('Mark as Cancelled')),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete Order', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildExpandedProducts(OrdersModel order, OrderManagementController controller) {
    final products = controller.orderProducts[order.id] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: products.map((product) {
          final productId = (product.productID as DocumentReference).id;
          final details = controller.productDetails[productId] ?? {};

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(left: 36, right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: details['imageUrl'] != ''
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      details['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image, size: 20, color: Colors.grey);
                      },
                    ),
                  )
                      : const Icon(Icons.image, size: 20, color: Colors.grey),
                ),
                Expanded(
                  child: Text(
                    details['name'] ?? 'Unknown Product',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  'Qty: ${product.productQuantity}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  'RM ${product.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          );
        }).toList(),
      ),
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