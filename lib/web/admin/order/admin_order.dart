import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../../view/widgets/order_status_utils.dart';
import '../widget/topbar.dart';
import 'admin_order_details.dart';

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
  Map<String, List<OrderProductModel>> orderProducts = {};
  Map<String, Map<String, dynamic>> productDetails = {};
  bool isLoading = true;
  String selectedTab = 'All';
  int currentPage = 1;
  int itemsPerPage = 10;
  Set<String> expandedOrders = {};

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
      Map<String, List<OrderProductModel>> orderProductsMap = {};
      Map<String, Map<String, dynamic>> productDetailsMap = {};

      // First, load all products for reference
      final productsSnapshot = await _firestore.collection('products').get();
      for (final productDoc in productsSnapshot.docs) {
        productDetailsMap[productDoc.id] = {
          'name': productDoc.data()['productName'] ?? 'Unknown Product',
          'imageUrl': (productDoc.data()['productURL'] as List?)?.first ?? '',
          'price': productDoc.data()['price'] ?? 0.0,
        };
      }

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        customerNameMap[userId] = userDoc.data()['name'] ?? userDoc.data()['email'] ?? userId;

        final ordersSnapshot = await userDoc.reference.collection('order').get();

        for (final orderDoc in ordersSnapshot.docs) {
          final orderData = orderDoc.data();
          final order = OrdersModel.fromJson(orderData, orderDoc.id);
          loadedOrders.add(order.copyWith(customerId: userId));

          // Load order products
          final orderProductsSnapshot = await orderDoc.reference.collection('orderProducts').get();
          List<OrderProductModel> products = [];

          for (final productDoc in orderProductsSnapshot.docs) {
            final productData = productDoc.data();
            products.add(OrderProductModel(
              price: productData['price']?.toDouble() ?? 0.0,
              productID: productData['productID'],
              productQuantity: productData['productQuantity'] ?? 1,
              totalPrice: productData['totalPrice']?.toDouble() ?? 0.0,
            ));
          }

          orderProductsMap[order.id] = products;
        }
      }

      setState(() {
        orders = loadedOrders;
        customerNames = customerNameMap;
        orderProducts = orderProductsMap;
        productDetails = productDetailsMap;
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
          case 'Pending Payment':
            return order.orderStatus.toLowerCase() == 'pending_payment';
          case 'Processing':
            return order.orderStatus.toLowerCase() == 'processing';
          case 'Delivered':
            return order.orderStatus.toLowerCase() == 'shipped';
          case 'Completed':
            return order.orderStatus.toLowerCase() == 'completed';
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
      ).toList();
    }

    setState(() {
      filteredOrders = filtered;
      currentPage = 1;
    });
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
          Expanded(
            child: Column(
              children: [
                const CustomTopBar(
                  title: 'Order Management',
                ),
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
                        // Orders table with expandable products
                        Expanded(
                          child: isLoading
                              ? Center(child: CircularProgressIndicator())
                              : SingleChildScrollView(
                            child: Column(
                              children: currentOrders.map((order) {
                                final products = orderProducts[order.id] ?? [];
                                final isExpanded = expandedOrders.contains(order.id);

                                return Container(
                                  margin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[200]!),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  child: Column(
                                    children: [
                                      // Main order row
                                      InkWell(
                                        onTap: () => setState(() {
                                          if (isExpanded) {
                                            expandedOrders.remove(order.id);
                                          } else {
                                            expandedOrders.add(order.id);
                                          }
                                        }),
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isExpanded ? Icons.expand_less : Icons.expand_more,
                                                color: Colors.grey[600],
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                flex: 2,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '#${order.shortOrderId}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
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
                                                  _formatDate(order.orderDate),
                                                  style: TextStyle(fontSize: 13),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  customerNames[order.customerId] ?? 'Unknown',
                                                  style: TextStyle(fontSize: 13),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  'RM ${order.totalAmount.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: OrderStatusUtils.getStatusColor(order.orderStatus).withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    _formatStatus(order.orderStatus),
                                                    style: TextStyle(
                                                      color: OrderStatusUtils.getStatusColor(order.orderStatus),
                                                      fontSize: 12,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              IconButton(
                                                icon: Icon(Icons.visibility_outlined),
                                                onPressed: () => OrderDetailsDialog.show(
                                                  context,
                                                  order: order,
                                                  products: orderProducts[order.id] ?? [],
                                                  productDetails: productDetails,
                                                  customerNames: customerNames,
                                                  firestore: _firestore,
                                                  onOrdersReload: _loadOrders,
                                                ),
                                                tooltip: 'View Details',
                                              ),
                                              PopupMenuButton<String>(
                                                icon: Icon(Icons.more_vert),
                                                onSelected: (value) {
                                                  if (value == 'delete') {
                                                    // Delete logic
                                                  } else {
                                                    OrderDetailsDialog.updateOrderStatus(
                                                      order,
                                                      value,
                                                      FirebaseFirestore.instance,
                                                      _loadOrders, // or whatever method reloads your orders
                                                      context,
                                                    );
                                                  }
                                                },
                                                itemBuilder: (BuildContext context) => [
                                                  PopupMenuItem(value: 'pending', child: Text('Mark as Pending')),
                                                  PopupMenuItem(value: 'processing', child: Text('Mark as Processing')),
                                                  PopupMenuItem(value: 'delivered', child: Text('Mark as Delivered')),
                                                  PopupMenuItem(value: 'cancelled', child: Text('Mark as Cancelled')),
                                                  PopupMenuDivider(),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text('Delete Order', style: TextStyle(color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Expandable products section
                                      if (isExpanded)
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            border: Border(
                                              top: BorderSide(color: Colors.grey[200]!),
                                            ),
                                          ),
                                          padding: EdgeInsets.all(16),
                                          child: Column(
                                            children: products.map((product) {
                                              final productId = (product.productID as DocumentReference).id;
                                              final details = productDetails[productId] ?? {};

                                              return Container(
                                                margin: EdgeInsets.only(bottom: 8),
                                                padding: EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      margin: EdgeInsets.only(left: 36, right: 12),
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
                                                            return Icon(Icons.image, size: 20, color: Colors.grey);
                                                          },
                                                        ),
                                                      )
                                                          : Icon(Icons.image, size: 20, color: Colors.grey),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        details['name'] ?? 'Unknown Product',
                                                        style: TextStyle(fontSize: 13),
                                                      ),
                                                    ),
                                                    Text(
                                                      'Qty: ${product.productQuantity}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                    SizedBox(width: 20),
                                                    Text(
                                                      'RM ${product.totalPrice.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    SizedBox(width: 40),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                    ],
                                  ),
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

// Create Order Dialog remains the same
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
  String orderType = 'General';
  String orderStatus = 'Pending';
  final TextEditingController _noteController = TextEditingController();

  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> selectedProducts = [];
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
          'stock': doc.data()['stockQuantity'] ?? 0,
        }).toList();

        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  void _addProduct() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String? selectedProductId;
        int quantity = 1;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Product'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedProductId,
                    decoration: InputDecoration(
                      labelText: 'Select Product',
                      border: OutlineInputBorder(),
                    ),
                    items: products.map<DropdownMenuItem<String>>((product) {
                      return DropdownMenuItem<String>(
                        value: product['id'],
                        child: Text('${product['name']} - RM${product['price']}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedProductId = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    initialValue: '1',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      quantity = int.tryParse(value) ?? 1;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedProductId != null ? () {
                    final product = products.firstWhere((p) => p['id'] == selectedProductId);
                    this.setState(() {
                      selectedProducts.add({
                        'id': product['id'],
                        'name': product['name'],
                        'price': product['price'],
                        'quantity': quantity,
                        'total': product['price'] * quantity,
                      });
                    });
                    Navigator.pop(context);
                  } : null,
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }

    try {
      // Calculate total
      double total = selectedProducts.fold(0, (sum, product) => sum + product['total']);

      // Create order in user's order subcollection
      final orderRef = await _firestore
          .collection('users')
          .doc(selectedCustomerId)
          .collection('order')
          .add({
        'orderDate': Timestamp.now(),
        'orderStatus': orderStatus.toLowerCase(),
        'totalAmount': total,
        'eligibilityForReturn': true,
        'shipmentID': null,
        'payment': 'pending',
      });

      // Add order products
      for (final product in selectedProducts) {
        await orderRef.collection('orderProducts').add({
          'price': product['price'],
          'productID': _firestore.collection('products').doc(product['id']),
          'productQuantity': product['quantity'],
          'totalPrice': product['total'],
        });
      }

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
        width: 700,
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
                      value: customer['id'],
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
                      child: DropdownButtonFormField<String>(
                        value: orderStatus,
                        decoration: InputDecoration(
                          labelText: 'Order Status',
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
                    ),
                  ],
                ),
                SizedBox(height: 30),

                // Products Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    TextButton.icon(
                      onPressed: _addProduct,
                      icon: Icon(Icons.add),
                      label: Text('Add Product'),
                    ),
                  ],
                ),
                SizedBox(height: 15),

                Container(
                  constraints: BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: selectedProducts.isEmpty
                      ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'No products added yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    itemCount: selectedProducts.length,
                    itemBuilder: (context, index) {
                      final product = selectedProducts[index];
                      return ListTile(
                        title: Text(product['name']),
                        subtitle: Text('Qty: ${product['quantity']} × RM${product['price']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'RM${product['total'].toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  selectedProducts.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                if (selectedProducts.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Divider(),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'RM${selectedProducts.fold(0.0, (sum, product) => sum + product['total']).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 20),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Order Note (Optional)',
                    hintText: 'Add note about order',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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