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
          case 'Inactive':
            return customer.status == 'inactive';
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Top Bar
          const CustomTopBar(title: 'Customer Management'),

          // Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Header Section
                  _buildHeaderSection(),

                  const SizedBox(height: 24),

                  // Filter Section
                  _buildFilterSection(),

                  const SizedBox(height: 24),

                  // Customer List/Grid
                  Expanded(
                    child: _buildCustomerContent(currentCustomers),
                  ),

                  const SizedBox(height: 20),

                  // Pagination
                  _buildPaginationSection(totalPages, startIndex, endIndex),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.people_outline,
                  color: Color(0xFF7C3AED),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Manage and monitor your customers',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _buildStatsCard('Total', '${customers.length}', Colors.blue),
              const SizedBox(width: 16),
              _buildStatsCard('Active', '${customers.where((c) => c.status == 'active').length}', Colors.green),
              const SizedBox(width: 16),
              _buildStatsCard('Inactive', '${customers.where((c) => c.status == 'inactive').length}', Colors.red),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search customers by name, email, or phone...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onChanged: (value) => _filterCustomers(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      isGridView = !isGridView;
                    });
                  },
                  icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
                  tooltip: isGridView ? 'List View' : 'Grid View',
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: 'Export',
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showAddCustomerDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add Customer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Filter by status:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(width: 16),
          _buildFilterChip('All', selectedFilter == 'All'),
          const SizedBox(width: 12),
          _buildFilterChip('Active', selectedFilter == 'Active'),
          const SizedBox(width: 12),
          _buildFilterChip('Blocked', selectedFilter == 'Blocked'),
          const Spacer(),
          Text(
            '${filteredCustomers.length} customers found',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerContent(List<CustomerModel> currentCustomers) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF7C3AED),
        ),
      );
    }

    if (currentCustomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No customers found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filter criteria',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isGridView
          ? GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: currentCustomers.length,
        itemBuilder: (context, index) {
          final customer = currentCustomers[index];
          return _buildCustomerCard(customer);
        },
      )
          : ListView.builder(
        padding: const EdgeInsets.all(4),
        itemCount: currentCustomers.length,
        itemBuilder: (context, index) {
          final customer = currentCustomers[index];
          return _buildCustomerListItem(customer);
        },
      ),
    );
  }

  Widget _buildCustomerCard(CustomerModel customer) {
    return InkWell(
      onTap: () => _showCustomerDetailsPage(customer),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF7C3AED),
                        const Color(0xFF7C3AED).withOpacity(0.8),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      customer.fullName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: customer.status == 'active' ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              customer.fullName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Color(0xFF1E293B),
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            const SizedBox(height: 3),
            Text(
              customer.email,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: customer.status == 'active'
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: customer.status == 'active'
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Text(
                customer.status.toUpperCase(),
                style: TextStyle(
                  color: customer.status == 'active' ? Colors.green[700] : Colors.red[700],
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _showCustomerDetailsPage(customer),
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7C3AED),
                    const Color(0xFF7C3AED).withOpacity(0.8),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  customer.fullName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: customer.status == 'active' ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          customer.fullName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          customer.email,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: customer.status == 'active'
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: customer.status == 'active'
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Text(
                customer.status.toUpperCase(),
                style: TextStyle(
                  color: customer.status == 'active' ? Colors.green[700] : Colors.red[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationSection(int totalPages, int startIndex, int endIndex) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1} to ${endIndex > filteredCustomers.length ? filteredCustomers.length : endIndex} of ${filteredCustomers.length} customers',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null,
                icon: const Icon(Icons.chevron_left),
                style: IconButton.styleFrom(
                  backgroundColor: currentPage > 1 ? Colors.grey[100] : Colors.grey[50],
                ),
              ),
              const SizedBox(width: 8),
              ...List.generate(
                totalPages > 5 ? 5 : totalPages,
                    (index) {
                  final pageNum = index + 1;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => setState(() => currentPage = pageNum),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentPage == pageNum
                            ? const Color(0xFF7C3AED)
                            : Colors.grey[100],
                        foregroundColor: currentPage == pageNum
                            ? Colors.white
                            : Colors.grey[700],
                        minimumSize: const Size(40, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text('$pageNum'),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: currentPage < totalPages ? () => setState(() => currentPage++) : null,
                icon: const Icon(Icons.chevron_right),
                style: IconButton.styleFrom(
                  backgroundColor: currentPage < totalPages ? Colors.grey[100] : Colors.grey[50],
                ),
              ),
            ],
          ),
        ],
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
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED) : Colors.grey[100],
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C3AED) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}