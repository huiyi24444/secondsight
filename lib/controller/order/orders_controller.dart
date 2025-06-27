import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../model/order_model.dart';
import '../../../model/return_request_model.dart';

class OrdersController extends ChangeNotifier {
  // Tab configuration
  static const List<String> tabTitles = [
    'All Orders',
    'To Pay',
    'To Ship',
    'To Receive',
    'Completed',
    'Returns',
    'Cancelled',
  ];

  static const List<String?> tabStatuses = [
    null, // All Orders - no filter
    'pending_payment',
    'processing',
    'shipped',
    'completed',
    'returns',
    'cancelled',
  ];

  late TabController _tabController;
  String? _userId;
  int _currentTabIndex = 0;

  // Getters
  TabController get tabController => _tabController;
  String? get userId => _userId;
  int get currentTabIndex => _currentTabIndex;
  int get tabLength => tabTitles.length;

  /// Initialize the controller with required dependencies
  void initialize({
    required TickerProvider vsync,
    required String userId,
  }) {
    _userId = userId;
    _tabController = TabController(length: tabTitles.length, vsync: vsync);
    _tabController.addListener(_onTabChanged);
  }

  /// Handle tab changes
  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _currentTabIndex = _tabController.index;
      notifyListeners();
    }
  }

  /// Get the appropriate empty message based on status
  String getEmptyMessage(String? status) {
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

  /// Build Firestore query for orders based on status filter
  Query<Map<String, dynamic>> buildOrdersQuery(String? statusFilter) {
    if (_userId == null) {
      throw StateError('User ID not initialized');
    }

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId!)
        .collection('order')
        .orderBy('orderDate', descending: true);

    if (statusFilter != null) {
      query = query.where('orderStatus', isEqualTo: statusFilter);
    }

    return query;
  }

  /// Build Firestore query for return requests
  Query<Map<String, dynamic>> buildReturnRequestsQuery() {
    if (_userId == null) {
      throw StateError('User ID not initialized');
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(_userId!)
        .collection('returnRequests')
        .orderBy('returnDate', descending: true);
  }

  /// Create OrdersModel from document data
  OrdersModel createOrderFromDocument(DocumentSnapshot doc) {
    return OrdersModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Create ReturnRequestModel from document data
  ReturnRequestModel createReturnRequestFromDocument(DocumentSnapshot doc) {
    return ReturnRequestModel.fromDocument(doc);
  }

  /// Get display text for order status
  String getStatusDisplayText(String status) {
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

  /// Check if current tab is return requests tab
  bool get isReturnRequestsTab => _currentTabIndex == tabStatuses.indexOf('returns');

  /// Get current tab status filter
  String? get currentTabStatusFilter => tabStatuses[_currentTabIndex];

  /// Navigate to specific tab
  void navigateToTab(int index) {
    if (index >= 0 && index < tabTitles.length) {
      _tabController.animateTo(index);
    }
  }

  /// Get tab title by index
  String getTabTitle(int index) {
    if (index >= 0 && index < tabTitles.length) {
      return tabTitles[index];
    }
    return '';
  }

  /// Get tab status by index
  String? getTabStatus(int index) {
    if (index >= 0 && index < tabStatuses.length) {
      return tabStatuses[index];
    }
    return null;
  }

  /// Refresh current tab data
  void refreshCurrentTab() {
    notifyListeners();
  }

  /// Handle order card tap
  void onOrderTap(OrdersModel order) {
    // This can be overridden or used with callbacks for navigation
    // Implementation depends on your navigation strategy
  }

  /// Handle return request card tap
  void onReturnRequestTap(ReturnRequestModel returnRequest) {
    // This can be overridden or used with callbacks for navigation
    // Implementation depends on your navigation strategy
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }
}