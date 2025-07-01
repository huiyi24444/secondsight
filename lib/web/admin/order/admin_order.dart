import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../model/order_model.dart';
import '../widget/topbar.dart';

class OrderManagementPage extends StatefulWidget {
  const OrderManagementPage({Key? key}) : super(key: key);

  @override
  State<OrderManagementPage> createState() => _OrderManagementPageState();
}

class _OrderManagementPageState extends State<OrderManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<OrdersModel> orders = [];
  List<OrdersModel> filteredOrders = [];
  bool isLoading = true;
  String selectedTab = 'All';
  int currentPage = 1;
  int itemsPerPage = 10;

  Map<String, String> customerNames = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => isLoading = true);
    try {
      final usersSnapshot = await _firestore.collection('users').get();

      List<OrdersModel> loadedOrders = [];
      Map<String, String> customerNameMap = {};

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        customerNameMap[userId] = userId;

        final ordersSnapshot = await userDoc.reference.collection('order').get();

        for (final orderDoc in ordersSnapshot.docs) {
          final orderData = orderDoc.data();
          final order = OrdersModel.fromJson(orderData, orderDoc.id);
          loadedOrders.add(order.copyWith(customerId: userId));
        }

      }

      setState(() {
        orders = loadedOrders;
        customerNames = customerNameMap;
        _filterOrders();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading orders: $e');
      setState(() => isLoading = false);
    }
  }



  void _filterOrders() {
    List<OrdersModel> filtered = orders;

    if (selectedTab != 'All') {
      filtered = filtered.where((order) {
        switch (selectedTab) {
          case 'Pending':
            return order.orderStatus.toLowerCase() == 'pending';
          case 'Processing':
            return order.orderStatus.toLowerCase() == 'processing';
          case 'Delivered':
            return order.orderStatus.toLowerCase() == 'delivered';
          case 'Cancelled':
            return order.orderStatus.toLowerCase() == 'cancelled';
          default:
            return true;
        }
      }).toList();
    }

    if (_searchController.text.isNotEmpty) {
      final search = _searchController.text.toLowerCase();
      filtered = filtered.where((order) =>
          order.shortOrderId.toLowerCase().contains(search)
        // you can also add customer name if it's linked
      ).toList();
    }

    setState(() {
      filteredOrders = filtered;
      currentPage = 1;
    });
  }


  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      final order = orders.firstWhere((o) => o.id == orderId);
      await _firestore
          .collection('users')
          .doc(order.customerId)
          .collection('order')
          .doc(order.id)
          .update({'orderStatus': newStatus});

      _loadOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating order: $e')),
      );
    }
  }


  void _showCreateOrderDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CreateOrderDialog(onOrderCreated: _loadOrders);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (filteredOrders.length / itemsPerPage).ceil();
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;
    final currentOrders = filteredOrders.sublist(
      startIndex,
      endIndex > filteredOrders.length ? filteredOrders.length : endIndex,
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                const CustomTopBar(
                  title: 'Order Management',
                ),
                // Content Area
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(20),
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
                        // Header with search and add button
                        Container(
                          padding: EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search order...',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onChanged: (value) => _filterOrders(),
                                ),
                              ),
                              SizedBox(width: 20),
                              ElevatedButton.icon(
                                onPressed: _showCreateOrderDialog,
                                icon: Icon(Icons.add),
                                label: Text('Create Order'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF7C3AED),
                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Filter tabs
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              _buildFilterTab('All', selectedTab == 'All'),
                              SizedBox(width: 20),
                              _buildFilterTab('Pending', selectedTab == 'Pending'),
                              SizedBox(width: 20),
                              _buildFilterTab('Processing', selectedTab == 'Processing'),
                              SizedBox(width: 20),
                              _buildFilterTab('Delivered', selectedTab == 'Delivered'),
                              SizedBox(width: 20),
                              _buildFilterTab('Cancelled', selectedTab == 'Cancelled'),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        // Orders table
                        Expanded(
                          child: isLoading
                              ? Center(child: CircularProgressIndicator())
                              : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                DataColumn(label: Container(width: 30, child: Checkbox(value: false, onChanged: (v) {}))),
                                DataColumn(label: Text('Order ID')),
                                DataColumn(label: Text('Product')),
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Customer')),
                                DataColumn(label: Text('Total')),
                                DataColumn(label: Text('Payment')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Action')),
                              ],
                              rows: currentOrders.map((order) {
                                return DataRow(
                                  cells: [
                                    DataCell(Checkbox(value: false, onChanged: (v) {})),
                                    DataCell(Text('#${order.shortOrderId}')),
                                    DataCell(Text(order.shipmentID ?? 'No shipment')),
                                    DataCell(Text(_formatDate(order.orderDate))),
                                    DataCell(Text(customerNames[order.customerId] ?? 'Unknown')),

                                    DataCell(Text('RM ${order.totalAmount.toStringAsFixed(2)}')),
                                    DataCell(Text('Mastercard')), // Placeholder for now
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(order.orderStatus).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _formatStatus(order.orderStatus),
                                          style: TextStyle(
                                            color: _getStatusColor(order.orderStatus),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert),
                                        onSelected: (value) {
                                          if (value == 'view') {
                                            // Navigate to order details
                                          } else if (value == 'delete') {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text('Delete Order'),
                                                content: Text('Are you sure you want to delete this order?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      Navigator.pop(context);
                                                      await _firestore.collection('order').doc(order.id).delete();
                                                      _loadOrders();
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red,
                                                    ),
                                                    child: Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          } else {
                                            _updateOrderStatus(order.id, value);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          PopupMenuItem(value: 'view', child: Text('View Details')),
                                          PopupMenuDivider(),
                                          PopupMenuItem(value: 'pending', child: Text('Mark as Pending')),
                                          PopupMenuItem(value: 'processing', child: Text('Mark as Processing')),
                                          PopupMenuItem(value: 'delivered', child: Text('Mark as Delivered')),
                                          PopupMenuItem(value: 'cancelled', child: Text('Mark as Cancelled')),
                                          PopupMenuDivider(),
                                          PopupMenuItem(value: 'delete', child: Text('Delete Order', style: TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        // Pagination
                        Container(
                          padding: EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Showing ${startIndex + 1} to ${endIndex > filteredOrders.length ? filteredOrders.length : endIndex} of ${filteredOrders.length} items'),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: currentPage > 1
                                        ? () => setState(() => currentPage--)
                                        : null,
                                    icon: Icon(Icons.chevron_left),
                                  ),
                                  ...List.generate(
                                    totalPages > 5 ? 5 : totalPages,
                                        (index) {
                                      final pageNum = index + 1;
                                      return Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: ElevatedButton(
                                          onPressed: () => setState(() => currentPage = pageNum),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: currentPage == pageNum
                                                ? Color(0xFF7C3AED)
                                                : Colors.grey[300],
                                            minimumSize: Size(40, 40),
                                          ),
                                          child: Text(
                                            '$pageNum',
                                            style: TextStyle(
                                              color: currentPage == pageNum
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    onPressed: currentPage < totalPages
                                        ? () => setState(() => currentPage++)
                                        : null,
                                    icon: Icon(Icons.chevron_right),
                                  ),
                                ],
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

  Widget _buildFilterTab(String title, bool isActive) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedTab = title;
          _filterOrders();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? Color(0xFF7C3AED) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Color(0xFF7C3AED) : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'processing':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1);
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonth(date.month)} ${date.year}';
  }


  String _getMonth(int month) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

// Create Order Dialog
class CreateOrderDialog extends StatefulWidget {
  final Function onOrderCreated;

  const CreateOrderDialog({Key? key, required this.onOrderCreated}) : super(key: key);

  @override
  State<CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _CreateOrderDialogState extends State<CreateOrderDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String? selectedCustomerId;
  String? selectedProductId;
  String orderType = 'General';
  String orderStatus = 'Pending';
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _noteController = TextEditingController();

  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> products = [];
  Map<String, dynamic> selectedProductDetails = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final customersSnapshot = await _firestore.collection('users').get();
      final productsSnapshot = await _firestore.collection('products').get();

      setState(() {
        customers = customersSnapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc.data()['name'] ?? 'Unknown',
          'email': doc.data()['email'] ?? '',
        }).toList();

        products = productsSnapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc.data()['productName'] ?? 'Unknown Product',
          'price': doc.data()['price'] ?? 0.0,
          'sku': doc.data()['sku'] ?? '',
        }).toList();

        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final quantity = int.parse(_quantityController.text);
      final total = selectedProductDetails['price'] * quantity;

      final orderData = {
        'orderId': 'ORD${DateTime.now().millisecondsSinceEpoch}'.substring(0, 10),
        'customerId': selectedCustomerId,
        'items': [{
          'productId': selectedProductId,
          'productName': selectedProductDetails['name'],
          'quantity': quantity,
          'price': selectedProductDetails['price'],
        }],
        'total': total,
        'orderStatus': orderStatus.toLowerCase(),
        'orderType': orderType,
        'note': _noteController.text,
        'date': DateTime.now().millisecondsSinceEpoch,
        'paymentMethod': 'Mastercard',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(selectedCustomerId)
          .collection('order')
          .add(orderData);




      Navigator.pop(context);
      widget.onOrderCreated();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: EdgeInsets.all(30),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create New Order',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: 30),
              if (isLoading)
                Center(child: CircularProgressIndicator())
              else ...[
                // Order Details
                Text('Order Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedCustomerId,
                  decoration: InputDecoration(
                    labelText: 'Select Customer',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: customers.map<DropdownMenuItem<String>>((customer) {
                    return DropdownMenuItem<String>(
                      value: customer['id'] as String, // ensure it's a String
                      child: Text('${customer['name']} (${customer['email']})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCustomerId = value;
                    });
                  },
                  validator: (value) => value == null ? 'Please select a customer' : null,
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: orderType,
                        decoration: InputDecoration(
                          labelText: 'Order Type',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: ['General', 'Express', 'Return'].map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            orderType = value!;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: TextFormField(
                        initialValue: DateTime.now().toString().split(' ')[0],
                        decoration: InputDecoration(
                          labelText: 'Order Date',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Order Note',
                    hintText: 'Add note about order',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                SizedBox(height: 30),

                // Add Products
                Text('Add Products to Your Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedProductId,
                  decoration: InputDecoration(
                    labelText: 'Search product name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.search),
                  ),
                  items: products.map<DropdownMenuItem<String>>((product) {
                    return DropdownMenuItem<String>(
                      value: product['id'] as String, // Ensure it's String
                      child: Text('${product['name']} - \$${product['price']}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedProductId = value;
                      selectedProductDetails = products.firstWhere((p) => p['id'] == value);
                    });
                  },
                  validator: (value) => value == null ? 'Please select a product' : null,
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter quantity';
                    if (int.tryParse(value) == null) return 'Please enter a valid number';
                    return null;
                  },
                ),
                SizedBox(height: 30),

                // Status
                Text('Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: orderStatus,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: ['Pending', 'Processing', 'Delivered', 'Cancelled'].map((status) {
                    return DropdownMenuItem(value: status, child: Text(status));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      orderStatus = value!;
                    });
                  },
                ),
                SizedBox(height: 30),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _createOrder,
                      child: Text('Create Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF7C3AED),
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}