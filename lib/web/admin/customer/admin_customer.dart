import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../model/user_model.dart';
import '../widget/topbar.dart';
import 'admin_customer_addition.dart';
import 'admin_customer_details.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({Key? key}) : super(key: key);

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<CustomerModel> customers = [];
  List<CustomerModel> filteredCustomers = [];
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
      final customersSnapshot = await _firestore.collection('users').get();

      Map<String, Map<String, dynamic>> customerOrderStats = {};

      for (var customerDoc in customersSnapshot.docs) {
        final customerId = customerDoc.id;
        final orderCollection = _firestore.collection('users').doc(customerId).collection('Order');
        final orderSnapshot = await orderCollection.get();

        if (orderSnapshot.docs.isNotEmpty) {
          for (var orderDoc in orderSnapshot.docs) {
            final data = orderDoc.data();

            if (!customerOrderStats.containsKey(customerId)) {
              customerOrderStats[customerId] = {
                'orderCount': 0,
                'totalSpent': 0.0,
                'lastOrderDate': 0,
              };
            }

            customerOrderStats[customerId]!['orderCount']++;
            customerOrderStats[customerId]!['totalSpent'] += data['total'] ?? 0.0;

            final orderDate = data['date'] ?? 0;
            if (orderDate > customerOrderStats[customerId]!['lastOrderDate']) {
              customerOrderStats[customerId]!['lastOrderDate'] = orderDate;
            }
          }
        }
      }

      List<CustomerModel> loadedCustomers = [];

      for (var doc in customersSnapshot.docs) {
        final data = doc.data();
        final stats = customerOrderStats[doc.id] ?? {
          'orderCount': 0,
          'totalSpent': 0.0,
          'lastOrderDate': 0,
        };

        final customer = CustomerModel.fromJson(data, doc.id);


        loadedCustomers.add(customer);
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
    List<CustomerModel> filtered = customers;

    // Filter by search
    if (_searchController.text.isNotEmpty) {
      final search = _searchController.text.toLowerCase();
      filtered = filtered.where((customer) {
        return customer.fullName.toLowerCase().contains(search) ||
            customer.email.toLowerCase().contains(search) ||
            customer.phoneNum.toString().contains(search);
      }).toList();
    }

    // Filter by status
    if (selectedFilter != 'All') {
      filtered = filtered.where((customer) {
        switch (selectedFilter) {
          case 'Active':
            return customer.status == 'active';
          case 'Blocked':
            return customer.status == 'blocked';
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


  void _showCustomerDetailsPage(CustomerModel customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailsPage(userId: customer.id),
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
    final List<CustomerModel> currentCustomers = filteredCustomers.sublist(
      startIndex,
      endIndex > filteredCustomers.length ? filteredCustomers.length : endIndex,
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
                  title: 'Customer',
                ),
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

  Widget _buildCustomerCard(CustomerModel customer) {
    return InkWell(
      onTap: () => _showCustomerDetailsPage(customer),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
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
                    customer.fullName.substring(0, 1).toUpperCase(),
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
                      color: customer.status == 'active' ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(customer.fullName, style: TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            Text(customer.email, style: TextStyle(color: Colors.grey[600], fontSize: 12), overflow: TextOverflow.ellipsis),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('Orders', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    //Text('${customer.orderCount}', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    Text('Balance', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    //Text('RM ${customer.balance.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: customer.status == 'active' ? Colors.green[100] : Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                customer.status,
                style: TextStyle(
                  color: customer.status == 'active' ? Colors.green[700] : Colors.red[700],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerListItem(CustomerModel customer) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
      ),
      child: ListTile(
        onTap: () => _showCustomerDetailsPage(customer),
        leading: CircleAvatar(
          backgroundColor: Colors.grey[300],
          child: Text(customer.fullName.substring(0, 1).toUpperCase()),
        ),
        title: Text(customer.fullName),
        subtitle: Text(customer.email),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
            ),
            SizedBox(width: 20),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: customer.status == 'active' ? Colors.green[100] : Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                customer.status,
                style: TextStyle(
                  color: customer.status == 'active' ? Colors.green[700] : Colors.red[700],
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
}

