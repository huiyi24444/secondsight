// Updated orders_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:secondsight/services/lazy_loading.dart';
import '../../services/auth_provider.dart';
import '../../model/order_model.dart';
import '../../model/return_request_model.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/order_card.dart';
import '../widgets/return_request_card.dart';
import 'order_details_view.dart';


class OrdersView extends StatefulWidget {
  const OrdersView({super.key});

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String userId;

  String _getEmptyMessage(String? status) {
    if (status == null) return 'You haven\'t placed any orders yet.';
    switch (status) {
      case 'pending_payment':
        return 'You have no pending payments.';
      case 'processing':
        return 'No orders are being prepared for shipping.';
      case 'shipped':
        return 'No orders are currently in transit.';
      case 'completed':
        return 'You haven\'t completed any orders yet.';
      case 'returns':
        return 'You haven\'t submitted any return requests.';
      case 'cancelled':
        return 'No cancelled orders found.';
      default:
        return 'No orders found for this status.';
    }
  }

  final List<String> _tabTitles = [
    'All Orders',
    'To Pay',
    'To Ship',
    'To Receive',
    'Completed',
    'Returns',
    'Cancelled',
  ];

  final List<String?> _tabStatuses = [
    null, // All Orders - no filter
    'pending_payment',
    'processing',
    'shipped',
    'completed',
    'returns',
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
        backgroundColor: Colors.transparent,
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
              (index) => _tabStatuses[index] == 'returns'
              ? _buildReturnRequestsList()
              : _buildOrdersList(_tabStatuses[index]),
        ),
      ),
    );
  }

  Widget _buildOrdersList(String? statusFilter) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('order')
        .orderBy('orderDate', descending: true);

    if (statusFilter != null) {
      query = query.where('orderStatus', isEqualTo: statusFilter);
    }

    return LazyLoadingList(
      query: query,
      itemBuilder: (doc) {
        final order = OrdersModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
        return OrderCard(order: order, userId: userId);
      },
        emptyMessage: _getEmptyMessage(statusFilter),
    );
  }



  Widget _buildReturnRequestsList() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('returnRequests')
        .orderBy('returnDate', descending: true);


    return LazyLoadingList(
      query: query,
      itemBuilder: (doc) {
        final returnRequest = ReturnRequestModel.fromDocument(doc);
        return ReturnRequestCard(
          returnRequest: returnRequest,
          userId: userId,
        );
      },
      emptyMessage: "No return requests found",
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
      case 'returns':
        return 'returns';
      case 'cancelled':
        return 'cancelled';
      default:
        return status;
    }
  }
}