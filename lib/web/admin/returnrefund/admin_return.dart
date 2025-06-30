import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReturnManagementPage extends StatefulWidget {
  const ReturnManagementPage({Key? key}) : super(key: key);

  @override
  State<ReturnManagementPage> createState() => _ReturnManagementPageState();
}

class _ReturnManagementPageState extends State<ReturnManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> returns = [];
  List<Map<String, dynamic>> filteredReturns = [];
  bool isLoading = true;
  String selectedTab = 'All';
  int currentPage = 1;
  int itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadReturns();
  }

  Future<void> _loadReturns() async {
    setState(() => isLoading = true);
    try {
      final returnsSnapshot = await _firestore.collection('Return').get();
      final ordersSnapshot = await _firestore.collection('Order').get();
      final customersSnapshot = await _firestore.collection('Customer').get();

      // Create maps for quick lookup
      Map<String, Map<String, dynamic>> orderMap = {};
      Map<String, Map<String, dynamic>> customerMap = {};

      for (var doc in ordersSnapshot.docs) {
        orderMap[doc.id] = doc.data();
      }

      for (var doc in customersSnapshot.docs) {
        customerMap[doc.id] = doc.data();
      }

      List<Map<String, dynamic>> loadedReturns = [];

      for (var doc in returnsSnapshot.docs) {
        final data = doc.data();
        final orderData = orderMap[data['orderId']] ?? {};
        final customerData = customerMap[orderData['customerId']] ?? {};

        loadedReturns.add({
          'id': doc.id,
          'returnId': data['returnId'] ?? doc.id.substring(0, 8).toUpperCase(),
          'orderId': data['orderId'] ?? '',
          'orderNumber': orderData['orderId'] ?? 'N/A',
          'date': data['date'] ?? DateTime.now().millisecondsSinceEpoch,
          'customer': customerData['name'] ?? 'Unknown Customer',
          'customerId': orderData['customerId'] ?? '',
          'total': data['refundAmount'] ?? orderData['total'] ?? 0.0,
          'status': data['status'] ?? 'pending',
          'reason': data['reason'] ?? 'Not specified',
          'items': data['items'] ?? [],
        });
      }

      setState(() {
        returns = loadedReturns;
        _filterReturns();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading returns: $e');
      setState(() => isLoading = false);
    }
  }

  void _filterReturns() {
    List<Map<String, dynamic>> filtered = returns;

    // Filter by tab
    if (selectedTab != 'All') {
      filtered = filtered.where((returnItem) {
        switch (selectedTab) {
          case 'Pending':
            return returnItem['status'] == 'pending';
          case 'Approved':
            return returnItem['status'] == 'approved';
          case 'Refunded':
            return returnItem['status'] == 'refunded';
          case 'Cancelled':
            return returnItem['status'] == 'cancelled';
          default:
            return true;
        }
      }).toList();
    }

    // Filter by search
    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((returnItem) {
        final search = _searchController.text.toLowerCase();
        return returnItem['returnId'].toLowerCase().contains(search) ||
            returnItem['orderNumber'].toLowerCase().contains(search) ||
            returnItem['customer'].toLowerCase().contains(search);
      }).toList();
    }

    setState(() {
      filteredReturns = filtered;
      currentPage = 1;
    });
  }

  Future<void> _updateReturnStatus(String returnId, String newStatus) async {
    try {
      await _firestore.collection('Return').doc(returnId).update({
        'status': newStatus,
      });

      // If refunded, update the order status as well
      if (newStatus == 'refunded') {
        final returnDoc = await _firestore.collection('Return').doc(returnId).get();
        final orderId = returnDoc.data()?['orderId'];
        if (orderId != null) {
          await _firestore.collection('Order').doc(orderId).update({
            'orderStatus': 'refunded',
          });
        }
      }

      _loadReturns();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Return status updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating return: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (filteredReturns.length / itemsPerPage).ceil();
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;
    final currentReturns = filteredReturns.sublist(
      startIndex,
      endIndex > filteredReturns.length ? filteredReturns.length : endIndex,
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
                                    hintText: 'Search return...',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onChanged: (value) => _filterReturns(),
                                ),
                              ),
                              SizedBox(width: 20),
                              ElevatedButton.icon(
                                onPressed: () {
                                  // Add return functionality
                                },
                                icon: Icon(Icons.add),
                                label: Text('Add Return'),
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
                              _buildFilterTab('Approved', selectedTab == 'Approved'),
                              SizedBox(width: 20),
                              _buildFilterTab('Refunded', selectedTab == 'Refunded'),
                              SizedBox(width: 20),
                              _buildFilterTab('Cancelled', selectedTab == 'Cancelled'),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        // Returns table
                        Expanded(
                          child: isLoading
                              ? Center(child: CircularProgressIndicator())
                              : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                DataColumn(label: Container(width: 30, child: Checkbox(value: false, onChanged: (v) {}))),
                                DataColumn(label: Text('Return ID')),
                                DataColumn(label: Text('Order ID')),
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Customer')),
                                DataColumn(label: Text('Total')),
                                DataColumn(label: Text('Payment')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Action')),
                              ],
                              rows: currentReturns.map((returnItem) {
                                return DataRow(
                                  cells: [
                                    DataCell(Checkbox(value: false, onChanged: (v) {})),
                                    DataCell(Text('#${returnItem['returnId']}')),
                                    DataCell(Text('#${returnItem['orderNumber']}')),
                                    DataCell(Text(_formatDate(returnItem['date']))),
                                    DataCell(Text(returnItem['customer'])),
                                    DataCell(Text('RM ${returnItem['total'].toStringAsFixed(2)}')),
                                    DataCell(Text('Mastercard')),
                                    DataCell(
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(returnItem['status']).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _formatStatus(returnItem['status']),
                                          style: TextStyle(
                                            color: _getStatusColor(returnItem['status']),
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
                                            _showReturnDetailsDialog(returnItem);
                                          } else if (value == 'delete') {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text('Delete Return'),
                                                content: Text('Are you sure you want to delete this return?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      Navigator.pop(context);
                                                      await _firestore.collection('Return').doc(returnItem['id']).delete();
                                                      _loadReturns();
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
                                            _updateReturnStatus(returnItem['id'], value);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          PopupMenuItem(value: 'view', child: Text('View Details')),
                                          PopupMenuDivider(),
                                          PopupMenuItem(value: 'pending', child: Text('Mark as Pending')),
                                          PopupMenuItem(value: 'approved', child: Text('Approve Return')),
                                          PopupMenuItem(value: 'refunded', child: Text('Process Refund')),
                                          PopupMenuItem(value: 'cancelled', child: Text('Cancel Return')),
                                          PopupMenuDivider(),
                                          PopupMenuItem(value: 'delete', child: Text('Delete Return', style: TextStyle(color: Colors.red))),
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
                              Text('Showing ${startIndex + 1} to ${endIndex > filteredReturns.length ? filteredReturns.length : endIndex} of ${filteredReturns.length} items'),
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

  void _showReturnDetailsDialog(Map<String, dynamic> returnItem) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Return Details'),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Return ID', '#${returnItem['returnId']}'),
              _buildDetailRow('Order ID', '#${returnItem['orderNumber']}'),
              _buildDetailRow('Customer', returnItem['customer']),
              _buildDetailRow('Date', _formatDate(returnItem['date'])),
              _buildDetailRow('Status', _formatStatus(returnItem['status'])),
              _buildDetailRow('Reason', returnItem['reason']),
              _buildDetailRow('Refund Amount', 'RM ${returnItem['total'].toStringAsFixed(2)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          if (returnItem['status'] == 'pending')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateReturnStatus(returnItem['id'], 'approved');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Approve Return'),
            ),
          if (returnItem['status'] == 'approved')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateReturnStatus(returnItem['id'], 'refunded');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF7C3AED),
              ),
              child: Text('Process Refund'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
          _buildMenuItem(Icons.dashboard, 'Dashboard', false),
          _buildMenuItem(Icons.shopping_cart, 'Product Management', false),
          _buildMenuItem(Icons.list_alt, 'Order Management', false),
          _buildMenuItem(Icons.assignment_return, 'Return Management', true),
          _buildMenuItem(Icons.people, 'Customer Management', false),
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
          // Navigation logic here
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
            'Return Management',
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

  Widget _buildFilterTab(String title, bool isActive) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedTab = title;
          _filterReturns();
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
      case 'approved':
        return Colors.green;
      case 'refunded':
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

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day} ${_getMonth(date.month)} ${date.year}';
  }

  String _getMonth(int month) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}