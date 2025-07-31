import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../model/user_model.dart';
import '../widget/topbar.dart';
import 'admin_customer_addition.dart';
import 'admin_customer_controller.dart';
import 'admin_customer_details.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({Key? key}) : super(key: key);

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  late final CustomerManagementController _controller;
  List<CustomerModel> customers = [];
  List<CustomerModel> filteredCustomers = [];
  bool isLoading = true;
  String selectedFilter = 'All';
  int currentPage = 1;
  int itemsPerPage = 12;

  @override
  void initState() {
    super.initState();
    _controller = CustomerManagementController(firestore: _firestore);
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => isLoading = true);
    try {
      final loadedCustomers = await _controller.loadCustomers();
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
    setState(() {
      String searchTerm = _searchController.text.toLowerCase();
      filteredCustomers = customers.where((customer) {
        bool matchesSearch = customer.fullName.toLowerCase().contains(searchTerm) ||
            customer.email.toLowerCase().contains(searchTerm);

        bool matchesFilter = selectedFilter == 'All' ||
            (selectedFilter == 'Active' && customer.status == 'active') ||
            (selectedFilter == 'Blocked' && customer.status != 'active');

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (filteredCustomers.length / itemsPerPage).ceil();
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, filteredCustomers.length);
    final currentCustomers = filteredCustomers.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const CustomTopBar(
                  title: 'Customer Management',
                ),
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
                        // Search & Add
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search customers...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onChanged: (_) => _filterCustomers(),
                                ),
                              ),
                              const SizedBox(width: 20),
                              ElevatedButton.icon(
                                onPressed: () => _controller.showAddCustomerDialog(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Customer'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tabs
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              _buildFilterTab('All'),
                              const SizedBox(width: 20),
                              _buildFilterTab('Active'),
                              const SizedBox(width: 20),
                              _buildFilterTab('Blocked'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Table
                        Expanded(
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: SizedBox(width: 30, child: Checkbox(value: false, onChanged: null))),
                                DataColumn(label: Text('Customer ID')),
                                DataColumn(label: Text('Full Name')),
                                DataColumn(label: Text('Email')),
                                DataColumn(label: Text('Phone')),
                                DataColumn(label: Text('Join Date')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Action')),
                              ],
                              rows: currentCustomers.map((customer) {
                                return DataRow(cells: [
                                  const DataCell(Checkbox(value: false, onChanged: null)),
                                  DataCell(Text('#${customer.id?.substring(0, 8) ?? 'N/A'}')),
                                  DataCell(Text(customer.fullName)),
                                  DataCell(Text(customer.email)),
                                  DataCell(Text(customer.phoneNum.toString())),
                                  DataCell(Text(_formatDate(customer.createdAt))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: customer.isVerified
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.red.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        customer.isVerified ? 'VERIFIED' : 'UNVERIFIED',
                                        style: TextStyle(
                                          color: customer.isVerified ? Colors.green[700] : Colors.red[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility_outlined),
                                          onPressed: () => _controller.showCustomerDetailsPage(context, customer),
                                          tooltip: 'View Details',
                                        ),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert),
                                          onSelected: (value) async {
                                            if (value == 'edit') {
                                              // Handle edit
                                            } else if (value == 'block') {
                                              // Handle block/unblock
                                              _toggleCustomerStatus(customer);
                                            } else if (value == 'delete') {
                                              _showDeleteDialog(customer);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit Customer'),
                                            ),
                                            PopupMenuItem(
                                              value: 'block',
                                              child: Text(customer.status == 'active' ? 'Block Customer' : 'Unblock Customer'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete Customer', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                        // Pagination
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Showing ${startIndex + 1} to $endIndex of ${filteredCustomers.length} items'),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: currentPage > 1
                                        ? () => setState(() => currentPage--)
                                        : null,
                                  ),
                                  ...List.generate(
                                    totalPages > 5 ? 5 : totalPages,
                                        (index) {
                                      final page = index + 1;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: ElevatedButton(
                                          onPressed: () => setState(() => currentPage = page),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: currentPage == page
                                                ? const Color(0xFF7C3AED)
                                                : Colors.grey[300],
                                            minimumSize: const Size(40, 40),
                                          ),
                                          child: Text(
                                            '$page',
                                            style: TextStyle(
                                              color: currentPage == page ? Colors.white : Colors.black,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: currentPage < totalPages
                                        ? () => setState(() => currentPage++)
                                        : null,
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

  Widget _buildFilterTab(String title) {
    final isActive = selectedFilter == title;

    return InkWell(
      onTap: () {
        setState(() {
          selectedFilter = title;
          _filterCustomers();
        });
      },
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _toggleCustomerStatus(CustomerModel customer) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(customer.status == 'active' ? 'Block Customer' : 'Unblock Customer'),
        content: Text(
          'Are you sure you want to ${customer.status == 'active' ? 'block' : 'unblock'} this customer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement status toggle logic
              await _loadCustomers();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: customer.status == 'active' ? Colors.red : Colors.green,
            ),
            child: Text(customer.status == 'active' ? 'Block' : 'Unblock'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(CustomerModel customer) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text('Are you sure you want to delete this customer? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement delete logic
              await _loadCustomers();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}