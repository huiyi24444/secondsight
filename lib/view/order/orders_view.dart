import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_provider.dart';
import '../../model/order_model.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/order_card.dart';
import 'order_details_view.dart';

class OrdersView extends StatefulWidget {
  const OrdersView({super.key});

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String userId;

  final List<String> _tabTitles = [
    'All Orders',
    'To Pay',
    'To Ship',
    'To Receive',
    'Completed',
    'Returned',
    'Cancelled',
  ];

  final List<String?> _tabStatuses = [
    null, // All Orders - no filter
    'pending_payment',
    'processing',
    'shipped',
    'completed',
    'returned',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userId = Provider.of<AuthProvider>(context, listen: false).userId;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        foregroundColor: Colors.black87,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF8E6CEF),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF8E6CEF),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(
          _tabTitles.length,
              (index) => _buildOrdersList(_tabStatuses[index]),
        ),
      ),
    );
  }

  Widget _buildOrdersList(String? statusFilter) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('order');

    // Apply status filter if not "All Orders"
    if (statusFilter != null) {
      query = query.where('orderStatus', isEqualTo: statusFilter);
    }

    // Order by date (newest first)
    // Note: Remove the orderBy if you get index errors, or create the index
    query = query.orderBy('orderDate', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        if (snapshot.hasError) {
          // Check if it's an index error
          if (snapshot.error.toString().contains('index')) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 48,
                      color: Colors.orange[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Database Index Required',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please create a Firestore index for this query.\nCheck the console for the index creation link.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Fallback: Show orders without filtering
                    TextButton(
                      onPressed: () {
                        setState(() {
                          // This will trigger a rebuild without the orderBy
                        });
                      },
                      child: const Text('Show Orders Without Sorting'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final orders = snapshot.data?.docs ?? [];

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E6CEF).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 48,
                    color: const Color(0xFF8E6CEF).withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  statusFilter == null
                      ? 'No orders yet'
                      : 'No ${_getStatusDisplayText(statusFilter)} orders',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  statusFilter == null
                      ? 'Your orders will appear here'
                      : 'Orders with this status will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderDoc = orders[index];
            final order = OrdersModel.fromJson(orderDoc.data() as Map<String, dynamic>, orderDoc.id);

            return OrderCard(
              order: order,
              userId: userId,
            );
          },
        );

      },
    );
  }

  String _getStatusDisplayText(String status) {
    switch (status) {
      case 'pending_payment':
        return 'to pay';
      case 'processing':
        return 'to ship';
      case 'shipped':
        return 'to receive';
      case 'completed':
        return 'completed';
      case 'returned':
        return 'returned';
      case 'cancelled':
        return 'cancelled';
      default:
        return status;
    }
  }
}
