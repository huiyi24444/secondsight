import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({Key? key}) : super(key: key);

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> filteredCustomers = [];
  bool isLoading = true;
  String selectedFilter = 'All';
  int currentPage = 1;
  int itemsPerPage = 12;
  bool isGridView = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => isLoading = true);
    try {
      final customersSnapshot = await _firestore.collection('Customer').get();
      final ordersSnapshot = await _firestore.collection('Order').get();

      // Calculate order statistics for each customer
      Map<String, Map<String, dynamic>> customerOrderStats = {};

      for (var order in ordersSnapshot.docs) {
        final customerId = order.data()['customerId'];
        if (customerId != null) {
          if (!customerOrderStats.containsKey(customerId)) {
            customerOrderStats[customerId] = {
              'orderCount': 0,
              'totalSpent': 0.0,
              'lastOrderDate': 0,
            };
          }

          customerOrderStats[customerId]!['orderCount']++;
          customerOrderStats[customerId]!['totalSpent'] += order.data()['total'] ?? 0.0;

          final orderDate = order.data()['date'] ?? 0;
          if (orderDate > customerOrderStats[customerId]!['lastOrderDate']) {
            customerOrderStats[customerId]!['lastOrderDate'] = orderDate;
          }
        }
      }

      List<Map<String, dynamic>> loadedCustomers = [];

      for (var doc in customersSnapshot.docs) {
        final data = doc.data();
        final stats = customerOrderStats[doc.id] ?? {
          'orderCount': 0,
          'totalSpent': 0.0,
          'lastOrderDate': 0,
        };

        loadedCustomers.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'phone': data['phoneNo'] ?? '',
          'address': data['address'] ?? {},
          'balance': data['balance'] ?? 0.0,
          'status': data['status'] ?? 'active',
          'createdAt': data['createdAt'],
          'orderCount': stats['orderCount'],
          'totalSpent': stats['totalSpent'],
          'lastOrderDate': stats['lastOrderDate'],
        });
      }

      setState(() {
        customers = loadedCustomers;
        _filterCustomers();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading customers: $e');
      setState(() => isLoading = false);
    }
  }

  void _filterCustomers() {
    List<Map<String, dynamic>> filtered = customers;

    // Filter by search
    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((customer) {
        final search = _searchController.text.toLowerCase();
        return customer['name'].toLowerCase().contains(search) ||
            customer['email'].toLowerCase().contains(search) ||
            customer['phone'].toLowerCase().contains(search);
      }).toList();
    }

    // Filter by status
    if (selectedFilter != 'All') {
      filtered = filtered.where((customer) {
        switch (selectedFilter) {
          case 'Active':
            return customer['status'] == 'active';
          case 'Blocked':
            return customer['status'] == 'blocked';
          default:
            return true;
        }
      }).toList();
    }

    setState(() {
      filteredCustomers = filtered;
      currentPage = 1;
    });
  }

  void _showCustomerDetailsPage(Map<String, dynamic> customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailsPage(customerId: customer['id']),
      ),
    );
  }

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddCustomerDialog(onCustomerAdded: _loadCustomers);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (filteredCustomers.length / itemsPerPage).ceil();
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;
    final currentCustomers = filteredCustomers.sublist(
      startIndex,
      endIndex > filteredCustomers.length ? filteredCustomers.length : endIndex,
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                _buildTopBar(),
                // Content Area
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Header with search and actions
                        Container(
                          padding: EdgeInsets.all(20),
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
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        hintText: 'Search customer...',
                                        prefixIcon: Icon(Icons.search),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey[300]!),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onChanged: (value) => _filterCustomers(),
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  IconButton(
                                    onPressed: () {
                                      // Export functionality
                                    },
                                    icon: Icon(Icons.upload),
                                    tooltip: 'Export',
                                  ),
                                  SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: _showAddCustomerDialog,
                                    icon: Icon(Icons.add),
                                    label: Text('Add Customer'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF7C3AED),
                                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      _buildFilterChip('All', selectedFilter == 'All'),
                                      SizedBox(width: 10),
                                      _buildFilterChip('Active', selectedFilter == 'Active'),
                                      SizedBox(width: 10),
                                      _buildFilterChip('Blocked', selectedFilter == 'Blocked'),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          // Filter functionality
                                        },
                                        icon: Icon(Icons.filter_list),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        // Customer list/grid
                        Expanded(
                          child: isLoading
                              ? Center(child: CircularProgressIndicator())
                              : isGridView
                              ? GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: 1.2,
                            ),
                            itemCount: currentCustomers.length,
                            itemBuilder: (context, index) {
                              final customer = currentCustomers[index];
                              return _buildCustomerCard(customer);
                            },
                          )
                              : ListView.builder(
                            itemCount: currentCustomers.length,
                            itemBuilder: (context, index) {
                              final customer = currentCustomers[index];
                              return _buildCustomerListItem(customer);
                            },
                          ),
                        ),
                        // Pagination
                        Container(
                          padding: EdgeInsets.all(20),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Showing ${startIndex + 1} to ${endIndex > filteredCustomers.length ? filteredCustomers.length : endIndex} of ${filteredCustomers.length} items'),
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

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    return InkWell(
      onTap: () => _showCustomerDetailsPage(customer),
      child: Container(
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
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[300],
                  child: Text(
                    customer['name'].substring(0, 1).toUpperCase(),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: customer['status'] == 'active' ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              customer['name'],
              style: TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              customer['email'],
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('Orders', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${customer['orderCount']}', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    Text('Balance', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('RM ${customer['balance'].toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: customer['status'] == 'active' ? Colors.green[100] : Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                customer['status'],
                style: TextStyle(
                  color: customer['status'] == 'active' ? Colors.green[700] : Colors.red[700],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerListItem(Map<String, dynamic> customer) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
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
      child: ListTile(
        onTap: () => _showCustomerDetailsPage(customer),
        leading: CircleAvatar(
          backgroundColor: Colors.grey[300],
          child: Text(customer['name'].substring(0, 1).toUpperCase()),
        ),
        title: Text(customer['name']),
        subtitle: Text(customer['email']),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Orders: ${customer['orderCount']}'),
                Text(
                  'Balance: RM ${customer['balance'].toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            SizedBox(width: 20),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: customer['status'] == 'active' ? Colors.green[100] : Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                customer['status'],
                style: TextStyle(
                  color: customer['status'] == 'active' ? Colors.green[700] : Colors.red[700],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedFilter = label;
          _filterCustomers();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF7C3AED) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: Color(0xFF7C3AED),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shopping_bag, color: Color(0xFF7C3AED)),
                ),
                SizedBox(width: 10),
                Text(
                  'Logo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }



  Widget _buildTopBar() {
    return Container(
      height: 60,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            'Customer',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'All Shop',
              style: TextStyle(color: Colors.orange[800]),
            ),
          ),
          SizedBox(width: 10),
          Icon(Icons.notifications_outlined),
          SizedBox(width: 10),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.person, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// Customer Details Page
class CustomerDetailsPage extends StatefulWidget {
  final String customerId;

  const CustomerDetailsPage({Key? key, required this.customerId}) : super(key: key);

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? customerData;
  List<Map<String, dynamic>> customerOrders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomerDetails();
  }

  Future<void> _loadCustomerDetails() async {
    try {
      final customerDoc = await _firestore.collection('Customer').doc(widget.customerId).get();
      final ordersSnapshot = await _firestore.collection('Order')
          .where('customerId', isEqualTo: widget.customerId)
          .get();

      List<Map<String, dynamic>> orders = [];
      double totalSpent = 0;

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        orders.add({
          'id': doc.id,
          'orderId': data['orderId'] ?? doc.id.substring(0, 8),
          'date': data['date'],
          'total': data['total'] ?? 0.0,
          'status': data['orderStatus'] ?? 'pending',
          'items': data['items'] ?? [],
        });
        totalSpent += data['total'] ?? 0.0;
      }

      setState(() {
        customerData = {
          ...customerDoc.data()!,
          'id': customerDoc.id,
          'totalOrders': orders.length,
          'totalSpent': totalSpent,
        };
        customerOrders = orders;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading customer details: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (customerData == null) {
      return Scaffold(
        body: Center(child: Text('Customer not found')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                _buildTopBar(),
                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Info Card
                        Container(
                          width: 350,
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
                          padding: EdgeInsets.all(30),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[300],
                                child: Text(
                                  customerData!['name'].substring(0, 1).toUpperCase(),
                                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                ),
                              ),
                              SizedBox(height: 20),
                              Text(
                                customerData!['name'],
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(Icons.shopping_cart, size: 16, color: Colors.orange[800]),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Customer ID: ${widget.customerId.substring(0, 8)}'),
                                ],
                              ),
                              SizedBox(height: 30),
                              _buildInfoRow('Customer ID', widget.customerId.substring(0, 8)),
                              _buildInfoRow('E-mail', customerData!['email'] ?? 'N/A'),
                              _buildInfoRow('Phone', customerData!['phoneNo'] ?? 'N/A'),
                              _buildInfoRow('Country', customerData!['address']?['country'] ?? 'N/A'),
                              _buildInfoRow('Address',
                                  '${customerData!['address']?['address1'] ?? ''} ${customerData!['address']?['address2'] ?? ''}'.trim()),
                              _buildInfoRow('Last Transaction',
                                  customerOrders.isNotEmpty
                                      ? _formatDate(customerOrders.first['date'])
                                      : 'No transactions'),
                              SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  // Delete account functionality
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[100],
                                  foregroundColor: Colors.red[700],
                                  minimumSize: Size(double.infinity, 45),
                                ),
                                child: Text('Delete Account'),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 20),
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
                                      customerData!['totalOrders'].toString(),
                                      Icons.receipt_long,
                                      Colors.blue,
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  Expanded(
                                    child: _buildSummaryCard(
                                      'Total Spent',
                                      'RM ${customerData!['totalSpent'].toStringAsFixed(2)}',
                                      Icons.attach_money,
                                      Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryCard(
                                      'Pending',
                                      customerOrders.where((o) => o['status'] == 'pending').length.toString(),
                                      Icons.pending,
                                      Colors.orange,
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  Expanded(
                                    child: _buildSummaryCard(
                                      'Completed',
                                      customerOrders.where((o) => o['status'] == 'completed').length.toString(),
                                      Icons.check_circle,
                                      Colors.purple,
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  Expanded(
                                    child: _buildSummaryCard(
                                      'Cancelled',
                                      customerOrders.where((o) => o['status'] == 'cancelled').length.toString(),
                                      Icons.cancel,
                                      Colors.red,
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  Expanded(
                                    child: _buildSummaryCard(
                                      'Returned',
                                      '0',
                                      Icons.assignment_return,
                                      Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                              // Transaction History
                              Container(
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
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Transaction History',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        Row(
                                          children: [
                                            TextButton(
                                              onPressed: () {},
                                              child: Text('View All'),
                                            ),
                                            SizedBox(width: 10),
                                            TextButton(
                                              onPressed: () {},
                                              child: Text('Filters'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 20),
                                    ...customerOrders.take(5).map((order) => _buildTransactionItem(order)).toList(),
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
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> order) {
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('#${order['orderId']}'),
          SizedBox(width: 20),
          Text(
            'Vintage Denim Jacket + ${order['items'].length - 1} other products',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Spacer(),
          Text('RM ${order['total'].toStringAsFixed(2)}'),
          SizedBox(width: 20),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(order['status']).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              order['status'],
              style: TextStyle(
                color: _getStatusColor(order['status']),
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(width: 20),
          Text(_formatDate(order['date'])),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(int? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day} ${_getMonth(date.month)} ${date.year}';
  }

  String _getMonth(int month) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: Color(0xFF7C3AED),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shopping_bag, color: Color(0xFF7C3AED)),
                ),
                SizedBox(width: 10),
                Text(
                  'Logo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildMenuItem(Icons.dashboard, 'Dashboard', false),
          _buildMenuItem(Icons.shopping_cart, 'Product Management', false),
          _buildMenuItem(Icons.list_alt, 'Order Management', false),
          _buildMenuItem(Icons.people, 'Customer Management', true),
          _buildMenuItem(Icons.report, 'Reports', false),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, bool isActive) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 60,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            'Customer Details',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'All Shop',
              style: TextStyle(color: Colors.orange[800]),
            ),
          ),
          SizedBox(width: 10),
          Icon(Icons.notifications_outlined),
          SizedBox(width: 10),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.person, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// Add Customer Dialog
class AddCustomerDialog extends StatefulWidget {
  final Function onCustomerAdded;

  const AddCustomerDialog({Key? key, required this.onCustomerAdded}) : super(key: key);

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String selectedCountry = 'MALAYSIA';

  bool isLoading = false;

  Future<void> _addCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final customerData = {
        'name': _nameController.text,
        'email': _emailController.text,
        'phoneNo': _phoneController.text,
        'address': {
          'country': selectedCountry,
        },
        'balance': 0.0,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('Customer').add(customerData);

      Navigator.pop(context);
      widget.onCustomerAdded();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Customer added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding customer: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
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
                    'Add a New Customer',
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
              Text('Customer Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Customer Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter customer name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Customer Email',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 120,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedCountry,
                      isExpanded: true,
                      underline: SizedBox(),
                      items: ['MALAYSIA', 'SINGAPORE', 'USA', 'UK'].map((
                          country) {
                        return DropdownMenuItem(
                          value: country,
                          child: Row(
                            children: [
                              Icon(Icons.flag, size: 16),
                              SizedBox(width: 5),
                              Text(country, style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCountry = value!;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter phone number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: isLoading ? null : _addCustomer,
                    child: isLoading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF7C3AED),
                      padding: EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
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
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
