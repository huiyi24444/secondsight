// FILE: views/customer_details_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondsight/view/widgets/order_status_utils.dart';
import '../../../admin_main.dart';
import '../../../model/order_model.dart';
import '../../../model/user_model.dart';
import '../../../view/widgets/dateTime_utils.dart';
import '../../../view/widgets/user_utils.dart';
import '../services/admin_auth_provider.dart';
import '../services/admin_nav.dart';
import '../widget/sidebar.dart';
import '../widget/topbar.dart';

class CustomerDetailsPage extends StatefulWidget {
  final String userId;

  const CustomerDetailsPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CustomerModel? customer;
  List<OrdersModel> customerOrders = [];
  bool isLoading = true;
  String currentPage = 'customers';
  final Map<String, String> _orderProductsCache = {};
  bool _showAllTransactions = false;

  @override
  void initState() {
    super.initState();
    _loadCustomerDetails();
  }

  Future<void> _loadCustomerDetails() async {
    try {
      final customerDoc = await _firestore.collection('users').doc(widget.userId).get();

      final ordersSnapshot = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('order')
          .get();

      List<OrdersModel> orders = [];

      for (var doc in ordersSnapshot.docs) {
        final order = OrdersModel.fromJson(doc.data(), doc.id);
        orders.add(order);
      }

      setState(() {
        customer = CustomerModel.fromJson(customerDoc.data()!, customerDoc.id);
        customerOrders = orders;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading customer details: $e');
      setState(() => isLoading = false);
    }
  }

  Future<String> _getOrderProductsDescription(String orderId) async {
    // Check cache first
    if (_orderProductsCache.containsKey(orderId)) {
      return _orderProductsCache[orderId]!;
    }

    try {
      // Get order products from subcollection
      final orderProductsSnapshot = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('order')
          .doc(orderId)
          .collection('orderProducts')
          .get();

      if (orderProductsSnapshot.docs.isEmpty) {
        _orderProductsCache[orderId] = 'No products found';
        return 'No products found';
      }

      List<String> productNames = [];

      // Get all product references first
      List<Future<DocumentSnapshot>> productFutures = [];
      List<int> quantities = [];

      for (var orderProductDoc in orderProductsSnapshot.docs) {
        final orderProductData = orderProductDoc.data();
        final productRef = orderProductData['productID'] as DocumentReference;
        final quantity = orderProductData['productQuantity'] as int;

        productFutures.add(productRef.get());
        quantities.add(quantity);
      }

      // Fetch all product details concurrently
      final productDocs = await Future.wait(productFutures);

      // Process results
      for (int i = 0; i < productDocs.length; i++) {
        final productDoc = productDocs[i];
        final quantity = quantities[i];

        if (productDoc.exists) {
          final productData = productDoc.data() as Map<String, dynamic>;
          final productName = productData['productName'] ?? 'Unknown Product';

          if (quantity > 1) {
            productNames.add('$productName (x$quantity)');
          } else {
            productNames.add(productName);
          }
        } else {
          productNames.add('Unknown Product');
        }
      }

      // Format the description
      String description;
      if (productNames.isEmpty) {
        description = 'No products found';
      } else if (productNames.length == 1) {
        description = productNames.first;
      } else if (productNames.length == 2) {
        description = '${productNames[0]} + ${productNames[1]}';
      } else {
        description = '${productNames[0]} + ${productNames.length - 1} more';
      }

      // Cache the result
      _orderProductsCache[orderId] = description;
      return description;

    } catch (e) {
      print('Error fetching order products: $e');
      final errorMsg = 'Error loading products';
      _orderProductsCache[orderId] = errorMsg;
      return errorMsg;
    }
  }


  @override
  Widget build(BuildContext context) {

    final adminProvider = Provider.of<AdminAuthProvider>(context);
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (customer == null) {
      return const Scaffold(
        body: Center(child: Text('Customer not found')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
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
          Expanded(
            child: Column(
              children: [
                const CustomTopBar(
                  title: 'Customer',
                  subtitle: 'Add Customer',
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Info Card
                        Container(
                          width: 350,
                          padding: const EdgeInsets.all(30),
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
                              CircleAvatar(
                                radius: 50,
                                backgroundImage: customer!.profilePic.isNotEmpty
                                    ? NetworkImage(customer!.profilePic)
                                    : null,
                                backgroundColor: Colors.grey[300],
                                child: customer!.profilePic.isEmpty
                                    ? Text(
                                  customer!.fullName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                )
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                customer!.fullName,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(Icons.verified_user,
                                        size: 16, color: customer!.isVerified ? Colors.green : Colors.grey),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('User ID: ${shortUserId(widget.userId)}'),
                                ],
                              ),
                              const SizedBox(height: 30),
                              _buildInfoRow('Email', customer!.email),
                              _buildInfoRow('Phone', customer!.phoneNum.toString()),
                              _buildInfoRow(
                                'Last Transaction',
                                customerOrders.isNotEmpty
                                    ? DateFormatter.formatDateTime(customerOrders.first.orderDate)
                                    : 'No transactions',
                              ),
                              const SizedBox(height: 20),
                              //ElevatedButton(
                              //                                 onPressed: () {
                              //                                   // Delete functionality
                              //                                 },
                              //                                 style: ElevatedButton.styleFrom(
                              //                                   backgroundColor: Colors.red[100],
                              //                                   foregroundColor: Colors.red[700],
                              //                                   minimumSize: const Size(double.infinity, 45),
                              //                                 ),
                              //                                 child: const Text('Delete Account'),
                              //                               ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Order Summary and History
                        Expanded(
                          child: Column(
                            children: [
                              // Summary Cards
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryCard(
                                      'Total Orders',
                                      customerOrders.length.toString(),
                                      Icons.receipt_long,
                                      Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: _buildSummaryCard(
                                      'Total Spent',
                                      'RM ${customerOrders.fold(0.0, (prev, o) => prev + o.totalAmount).toStringAsFixed(2)}',
                                      Icons.attach_money,
                                      Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  _buildOrderCountCard('Pending', 'pending', Colors.orange),
                                  _buildOrderCountCard('Completed', 'completed', Colors.purple),
                                  _buildOrderCountCard('Cancelled', 'cancelled', Colors.red),
                                  _buildSummaryCard('Returned', '0', Icons.assignment_return, Colors.grey),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Transaction History
                              Container(
                                padding: const EdgeInsets.all(20),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Transaction History',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        Row(
                                          children: [
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _showAllTransactions = !_showAllTransactions;
                                                });
                                              },
                                              child: Text(_showAllTransactions ? 'Show Less' : 'View All'),
                                            ),
                                            const SizedBox(width: 10),
                                            TextButton(onPressed: () {}, child: const Text('Filters')),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    // Show transactions based on the toggle
                                    ...(_showAllTransactions
                                        ? customerOrders
                                        : customerOrders.take(5)
                                    ).map(_buildTransactionItem).toList(),

                                    // Show count if there are more items
                                    if (!_showAllTransactions && customerOrders.length > 5) ...[
                                      const SizedBox(height: 16),
                                      Center(
                                        child: Text(
                                          '${customerOrders.length - 5} more transactions',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCountCard(String label, String status, Color color) {
    final count = customerOrders.where((o) => o.orderStatus == status).length;
    return _buildSummaryCard(label, count.toString(), Icons.circle, color);
  }


  Widget _buildTransactionItem(OrdersModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Order ID - Fixed width
          SizedBox(
            width: 90,
            child: Text(
              '#${order.shortOrderId}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 24),
          // Product Description - Flexible width
          Expanded(
            flex: 3,
            child: FutureBuilder<String>(
              future: _getOrderProductsDescription(order.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Text(
                    'Loading products...',
                    style: TextStyle(color: Colors.grey[600]),
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    'Error loading products',
                    style: TextStyle(color: Colors.red[600]),
                  );
                }

                return Text(
                  snapshot.data ?? 'No products found',
                  style: TextStyle(color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                );
              },
            ),
          ),

          const SizedBox(width: 16),

          // Total Amount - Fixed width
          SizedBox(
            width: 80,
            child: Text(
              'RM ${order.totalAmount.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
            ),
          ),

          const SizedBox(width: 16),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: OrderStatusUtils.getStatusColor(order.orderStatus).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
                OrderStatusUtils.getStatusDisplayText(order.orderStatus),
              style: TextStyle(
                color: OrderStatusUtils.getStatusColor(order.orderStatus),
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Order Date - Fixed width
          SizedBox(
            width: 100,
            child: Text(
              DateFormatter.formatDate(order.orderDate),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  }

