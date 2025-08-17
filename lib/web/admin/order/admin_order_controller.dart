// admin_order_controller.dart (Updated with bulk selection)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:secondsight/controller/order/notif_controller.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';



class OrderManagementController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController searchController = TextEditingController();

  List<OrdersModel> _orders = [];
  List<OrdersModel> _filteredOrders = [];
  Map<String, List<OrderProductModel>> _orderProducts = {};
  Map<String, Map<String, dynamic>> _productDetails = {};
  Map<String, String> _customerNames = {};

  // Bulk selection properties
  Map<String, bool> _selectedOrders = {};
  Map<String, TextEditingController> _trackingControllers = {};
  bool _bulkMode = false;

  bool _isLoading = true;
  String _selectedTab = 'All';
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  // New properties for overdue functionality
  bool _showOverdueOnly = false;
  SortOption _currentSort = SortOption.dateNewest;



  // Getters
  List<OrdersModel> get orders => _orders;
  List<OrdersModel> get filteredOrders => _filteredOrders;
  Map<String, List<OrderProductModel>> get orderProducts => _orderProducts;
  Map<String, Map<String, dynamic>> get productDetails => _productDetails;
  Map<String, String> get customerNames => _customerNames;
  Map<String, bool> get selectedOrders => _selectedOrders;
  Map<String, TextEditingController> get trackingControllers => _trackingControllers;
  bool get bulkMode => _bulkMode;
  bool get isLoading => _isLoading;
  String get selectedTab => _selectedTab;
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  bool get showOverdueOnly => _showOverdueOnly;
  SortOption get currentSort => _currentSort;

  // Computed properties
  int get totalPages => (_filteredOrders.length / _itemsPerPage).ceil();
  int get startIndex => (_currentPage - 1) * _itemsPerPage;
  int get endIndex => startIndex + _itemsPerPage;
  int get selectedCount => _selectedOrders.values.where((selected) => selected).length;

  // Advanced Filter Properties
  String _selectedStatusFilter = 'All Statuses';
  DateRange _selectedDateRange = DateRange.all;
  String _selectedPaymentMethod = 'All Methods';
  String _selectedProductCountFilter = 'All Counts';
  DateTimeRange? _customDateRange;

  final TextEditingController minAmountController = TextEditingController();
  final TextEditingController maxAmountController = TextEditingController();

  // ADD NEW GETTERS:
  String get selectedStatusFilter => _selectedStatusFilter;
  DateRange get selectedDateRange => _selectedDateRange;
  String get selectedPaymentMethod => _selectedPaymentMethod;
  String get selectedProductCountFilter => _selectedProductCountFilter;
  DateTimeRange? get customDateRange => _customDateRange;

  bool get hasActiveFilters {
    return _selectedStatusFilter != 'All Statuses' ||
        _selectedDateRange != DateRange.all ||
        _selectedPaymentMethod != 'All Methods' ||
        _selectedProductCountFilter != 'All Counts' ||
        minAmountController.text.isNotEmpty ||
        maxAmountController.text.isNotEmpty;
  }




  // Check if all "to_ship" orders are selected
  bool get allToShipSelected {
    final toShipOrders = _filteredOrders.where((order) =>
    order.orderStatus.toLowerCase() == 'to_ship').toList();
    if (toShipOrders.isEmpty) return false;
    return toShipOrders.every((order) => _selectedOrders[order.id] ?? false);
  }

  // New computed property for overdue count
  int get overdueOrdersCount => _orders.where((order) => isOrderOverdue(order)).length;

  List<OrdersModel> get currentOrders => _filteredOrders.sublist(
    startIndex,
    endIndex > _filteredOrders.length ? _filteredOrders.length : endIndex,
  );

  OrderManagementController() {
    searchController.addListener(_onSearchChanged);
    loadOrders();
  }

  void _onSearchChanged() {
    filterOrders();
  }

  // Toggle bulk mode
  void toggleBulkMode() {
    _bulkMode = !_bulkMode;
    if (!_bulkMode) {
      // Clear selections when exiting bulk mode
      _selectedOrders.clear();
    }
    notifyListeners();
  }

  // Toggle individual order selection
  void toggleOrderSelection(String orderId) {
    _selectedOrders[orderId] = !(_selectedOrders[orderId] ?? false);
    notifyListeners();
  }

  // Toggle all "to_ship" orders selection
  void toggleSelectAll() {
    final toShipOrders = _filteredOrders.where((order) =>
    order.orderStatus.toLowerCase() == 'to_ship').toList();

    final shouldSelectAll = !allToShipSelected;

    for (final order in toShipOrders) {
      _selectedOrders[order.id] = shouldSelectAll;
    }
    notifyListeners();
  }

  // Get tracking controller for an order
  TextEditingController getTrackingController(String orderId) {
    if (!_trackingControllers.containsKey(orderId)) {
      _trackingControllers[orderId] = TextEditingController();
    }
    return _trackingControllers[orderId]!;
  }

  // Check if an order is overdue
  bool isOrderOverdue(OrdersModel order) {
    if (order.orderStatus.toLowerCase() != 'to_ship') return false;

    final today = DateTime.now();
    final orderDateOnly = DateTime(order.orderDate.year, order.orderDate.month, order.orderDate.day);
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    return orderDateOnly.isBefore(todayDateOnly);
  }

  // Get days overdue
  int getDaysOverdue(OrdersModel order) {
    if (!isOrderOverdue(order)) return 0;

    final today = DateTime.now();
    final difference = today.difference(order.orderDate);
    return difference.inDays;
  }

  Future<void> loadOrders() async {
    _setLoading(true);
    try {
      final usersSnapshot = await _firestore.collection('users').get();

      List<OrdersModel> loadedOrders = [];
      Map<String, String> customerNameMap = {};
      Map<String, List<OrderProductModel>> orderProductsMap = {};
      Map<String, Map<String, dynamic>> productDetailsMap = {};

      // Load all products for reference
      final productsSnapshot = await _firestore.collection('products').get();
      for (final productDoc in productsSnapshot.docs) {
        productDetailsMap[productDoc.id] = {
          'name': productDoc.data()['productName'] ?? 'Unknown Product',
          'imageUrl': (productDoc.data()['productURL'] as List?)?.first ?? '',
          'price': productDoc.data()['price'] ?? 0.0,
        };
      }

      // Load orders for each user
      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        customerNameMap[userId] = userId;

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

      _orders = loadedOrders;
      _customerNames = customerNameMap;
      _orderProducts = orderProductsMap;
      _productDetails = productDetailsMap;

      filterOrders();
    } catch (e) {
      print('Error loading orders: $e');
    } finally {
      _setLoading(false);
    }
  }
  String _generateTrackingNumber() {
    final now = DateTime.now();
    final randomSuffix = (DateTime.now().microsecond % 10000).toString().padLeft(4, '0');

    // Format: SS + YYMMDD + HHMMSS + XXXX
    // SS = SecondSight, YYMMDD = date, HHMMSS = time, XXXX = random suffix
    final trackingNumber = 'SS${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}$randomSuffix';

    return trackingNumber;
  }

  Future<Map<String, dynamic>> bulkUpdateOrders({String? lastUpdatedBy}) async {
    final selectedOrderIds = _selectedOrders.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    int successCount = 0;
    int failCount = 0;
    List<String> errors = [];
    List<String> generatedTrackingNumbers = []; // Track generated numbers for confirmation

    for (final orderId in selectedOrderIds) {
      final order = _orders.firstWhere((o) => o.id == orderId);

      // Auto-generate tracking number for each order
      final trackingNumber = _generateTrackingNumber();
      // Add small delay to ensure unique tracking numbers
      await Future.delayed(const Duration(milliseconds: 10));

      try {
        // Prepare update data with proper date tracking
        Map<String, dynamic> orderUpdateData = {
          'orderStatus': 'to_receive',
          'toReceiveDate': FieldValue.serverTimestamp(),
          'lastStatusUpdate': FieldValue.serverTimestamp(),
        };

        // Add lastUpdatedBy if provided
        if (lastUpdatedBy != null) {
          orderUpdateData['lastUpdatedBy'] = lastUpdatedBy;
        }

        // Update order status with date tracking
        await _firestore
            .collection('users')
            .doc(order.customerId)
            .collection('order')
            .doc(orderId)
            .update(orderUpdateData);

        // Update or create shipment document
        final shipmentRef = _firestore
            .collection('users')
            .doc(order.customerId)
            .collection('order')
            .doc(orderId)
            .collection('shipment');

        final shipmentSnapshot = await shipmentRef.get();

        final shipmentData = {
          'trackingNumber': trackingNumber,
          'shippedDate': FieldValue.serverTimestamp(),
        };

        if (shipmentSnapshot.docs.isNotEmpty) {
          await shipmentSnapshot.docs.first.reference.update(shipmentData);
        } else {
          await shipmentRef.add(shipmentData);
        }

        final orderProductsSnapshot = await _firestore
            .collection('users')
            .doc(order.customerId)
            .collection('order')
            .doc(orderId)
            .collection('orderProducts')
            .get();

        final itemCount = orderProductsSnapshot.size;

        // Create shipment notification with tracking number
        await _firestore.collection('notifications').add({
          'userId': order.customerId,
          'title': 'Order Shipped',
          'message': 'Your order #${order.shortOrderId} has been shipped! Tracking number: $trackingNumber',
          'type': 'order_status',
          'orderId': order.id,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'metadata': {
            'orderStatus': 'to_receive',
            'trackingNumber': trackingNumber,
            'itemCount': itemCount,
            'totalAmount': order.totalAmount,
          },
        });

        generatedTrackingNumbers.add('${order.shortOrderId}: $trackingNumber');
        successCount++;
      } catch (e) {
        errors.add('Order #${order.shortOrderId}: $e');
        failCount++;
      }
    }

    // Clear selections and exit bulk mode on success
    if (successCount > 0) {
      _selectedOrders.clear();
      _bulkMode = false;
      await loadOrders();
    }

    return {
      'success': successCount,
      'failed': failCount,
      'errors': errors,
      'trackingNumbers': generatedTrackingNumbers, // Include generated tracking numbers
    };
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void filterOrders() {
    List<OrdersModel> filtered = _orders;

    // Existing status filter (from tabs)
    if (_selectedTab != 'All') {
      filtered = filtered.where((order) {
        switch (_selectedTab) {
          case 'To Ship':
            return order.orderStatus.toLowerCase() == 'to_ship';
          case 'To Receive':
            return order.orderStatus.toLowerCase() == 'to_receive';
          case 'Completed':
            return order.orderStatus.toLowerCase() == 'completed';
          case 'Cancelled':
            return order.orderStatus.toLowerCase() == 'cancelled';
          default:
            return true;
        }
      }).toList();
    }

    // ADD ADVANCED FILTERS:

    // Additional Status Filter
    if (_selectedStatusFilter != 'All Statuses') {
      filtered = filtered.where((order) =>
      order.orderStatus.toLowerCase() == _selectedStatusFilter.toLowerCase()).toList();
    }

    // Date Range Filter
    if (_selectedDateRange != DateRange.all) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      filtered = filtered.where((order) {
        final orderDate = DateTime(order.orderDate.year, order.orderDate.month, order.orderDate.day);

        switch (_selectedDateRange) {
          case DateRange.today:
            return orderDate.isAtSameMomentAs(today);
          case DateRange.yesterday:
            return orderDate.isAtSameMomentAs(today.subtract(Duration(days: 1)));
          case DateRange.last7Days:
            return orderDate.isAfter(today.subtract(Duration(days: 7)));
          case DateRange.last30Days:
            return orderDate.isAfter(today.subtract(Duration(days: 30)));
          case DateRange.thisMonth:
            return orderDate.year == now.year && orderDate.month == now.month;
          case DateRange.lastMonth:
            final lastMonth = DateTime(now.year, now.month - 1);
            return orderDate.year == lastMonth.year && orderDate.month == lastMonth.month;
          case DateRange.custom:
            if (_customDateRange != null) {
              return orderDate.isAfter(_customDateRange!.start.subtract(Duration(days: 1))) &&
                  orderDate.isBefore(_customDateRange!.end.add(Duration(days: 1)));
            }
            return true;
          default:
            return true;
        }
      }).toList();
    }

    // Amount Range Filter
    if (minAmountController.text.isNotEmpty || maxAmountController.text.isNotEmpty) {
      filtered = filtered.where((order) {
        final amount = order.totalAmount;
        final minAmount = double.tryParse(minAmountController.text) ?? 0.0;
        final maxAmount = double.tryParse(maxAmountController.text) ?? double.infinity;

        return amount >= minAmount && amount <= maxAmount;
      }).toList();
    }

    // Product Count Filter
    if (_selectedProductCountFilter != 'All Counts') {
      filtered = filtered.where((order) {
        final productCount = _orderProducts[order.id]?.length ?? 0;

        switch (_selectedProductCountFilter) {
          case '1':
            return productCount == 1;
          case '2-5':
            return productCount >= 2 && productCount <= 5;
          case '6-10':
            return productCount >= 6 && productCount <= 10;
          case '10+':
            return productCount > 10;
          default:
            return true;
        }
      }).toList();
    }

    // Existing search filter
    if (searchController.text.isNotEmpty) {
      final search = searchController.text.toLowerCase();
      filtered = filtered.where((order) =>
      order.shortOrderId.toLowerCase().contains(search) ||
          (_customerNames[order.customerId] ?? '').toLowerCase().contains(search)
      ).toList();
    }

    // Existing overdue filter
    if (_showOverdueOnly) {
      filtered = filtered.where((order) => isOrderOverdue(order)).toList();
    }

    // MODIFY SORTING to include new options:
    switch (_currentSort) {
      case SortOption.dateNewest:
        filtered.sort((a, b) => b.orderDate.compareTo(a.orderDate));
        break;
      case SortOption.dateOldest:
        filtered.sort((a, b) => a.orderDate.compareTo(b.orderDate));
        break;
      case SortOption.overdueFirst:
        filtered.sort((a, b) {
          final aOverdue = isOrderOverdue(a);
          final bOverdue = isOrderOverdue(b);
          if (aOverdue && !bOverdue) return -1;
          if (!aOverdue && bOverdue) return 1;
          return b.orderDate.compareTo(a.orderDate);
        });
        break;
      case SortOption.amountHighLow:
        filtered.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        break;
      case SortOption.amountLowHigh:
        filtered.sort((a, b) => a.totalAmount.compareTo(b.totalAmount));
        break;
      case SortOption.customerAZ:
        filtered.sort((a, b) => (_customerNames[a.customerId] ?? '')
            .compareTo(_customerNames[b.customerId] ?? ''));
        break;
      case SortOption.customerZA:
        filtered.sort((a, b) => (_customerNames[b.customerId] ?? '')
            .compareTo(_customerNames[a.customerId] ?? ''));
        break;
    }

    _filteredOrders = filtered;
    _currentPage = 1;
    notifyListeners();
  }

  void toggleOverdueOnly() {
    _showOverdueOnly = !_showOverdueOnly;
    filterOrders();
  }

  void setSortOption(SortOption option) {
    _currentSort = option;
    filterOrders();
  }

  void setSelectedTab(String tab) {
    _selectedTab = tab;
    filterOrders();
  }

  void setCurrentPage(int page) {
    _currentPage = page;
    notifyListeners();
  }

  Future<void> updateOrderStatus(OrdersModel order, String newStatus) async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();

      for (final userDoc in usersSnapshot.docs) {
        final orderDoc = await userDoc.reference.collection('order').doc(order.id).get();
        if (orderDoc.exists) {
          await orderDoc.reference.update({'orderStatus': newStatus});
          break;
        }
      }

      await loadOrders();
    } catch (e) {
      print('Error updating order status: $e');
    }
  }

  Future<void> deleteOrder(OrdersModel order) async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();

      for (final userDoc in usersSnapshot.docs) {
        final orderDoc = await userDoc.reference.collection('order').doc(order.id).get();
        if (orderDoc.exists) {
          final orderProductsSnapshot = await orderDoc.reference.collection('orderProducts').get();
          for (final productDoc in orderProductsSnapshot.docs) {
            await productDoc.reference.delete();
          }

          await orderDoc.reference.delete();
          break;
        }
      }

      await loadOrders();
    } catch (e) {
      print('Error deleting order: $e');
    }
  }

  String formatDate(DateTime date) {
    final formatter = DateFormat('d MMM yyyy | h:mm a');
    return formatter.format(date);
  }

  Future<void> updateOrderCancellation({
    required String customerId,
    required String orderId,
    required String cancellationReason,
    String? cancelNote,
  }) async {
    try {
      // First, verify the order can be cancelled
      final orderDoc = await _firestore
          .collection('users')
          .doc(customerId)
          .collection('order')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      final currentStatus = orderData['orderStatus']?.toString().toLowerCase();

      if (currentStatus != 'to_ship') {
        throw Exception('Only orders with "To Ship" status can be cancelled');
      }

      // Get order details for refund
      final orderTotal = ((orderData['totalAmount'] ?? 0.0) as double) - 8;
      final paymentMethod = orderData['paymentMethod'] ?? 'Original Payment Method';
      final payment = orderData['payment'] ?? 'Unknown'; // This will be used as transactionId

      // Create document references
      final cancellationRef = _firestore.collection('cancellation').doc();
      final refundRef = _firestore.collection('refunds').doc();

      // Prepare cancellation data using the enhanced CancellationModel structure
      final cancellationData = {
        'referenceID': orderId,
        'cancellationType': 'order', // Specify this is an order cancellation
        'cancelReason': cancellationReason,
        'cancelDate': FieldValue.serverTimestamp(),
        'cancelNote': cancelNote,
        'cancelledBy': 'admin', // Since this is from admin panel
        // Include legacy field for backward compatibility
        'orderID': orderId,
      };

      // Prepare refund data using the RefundModel structure
      final refundData = {
        'orderId': orderId,
        'returnRequestId': null, // null for cancellation refunds
        'cancelId': cancellationRef.id,
        'refundAmount': orderTotal,
        'refundMethod': paymentMethod,
        'refundDate': FieldValue.serverTimestamp(),
        'transactionId': payment, // Use 'payment' attribute as transactionId
        'customerId': customerId,
        'refundType': 'cancellation',
      };

      // Use batch write for atomicity
      final batch = _firestore.batch();

      // Create cancellation document
      batch.set(cancellationRef, cancellationData);

      // Create refund document in top-level 'refunds' collection
      batch.set(refundRef, refundData);

      // Update order document
      batch.update(
        _firestore
            .collection('users')
            .doc(customerId)
            .collection('order')
            .doc(orderId),
        {
          'orderStatus': 'cancelled',
          'cancelDate': FieldValue.serverTimestamp(),
          'cancelID': cancellationRef.id,
          'refundID': refundRef.id, // Link to refund document
        },
      );

      // Commit batch
      await batch.commit();

      // Refresh the orders after cancellation
      await loadOrders();

    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();

    // ADD THESE LINES:
    minAmountController.dispose();
    maxAmountController.dispose();

    // Dispose all tracking controllers
    _trackingControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }


  void setStatusFilter(String status) {
    _selectedStatusFilter = status;
    applyAdvancedFilters();
  }

  void setDateRange(DateRange range) {
    _selectedDateRange = range;
    if (range != DateRange.custom) {
      _customDateRange = null;
    }
    applyAdvancedFilters();
  }

  void setCustomDateRange(DateTimeRange range) {
    _customDateRange = range;
    applyAdvancedFilters();
  }

  void setPaymentMethodFilter(String method) {
    _selectedPaymentMethod = method;
    applyAdvancedFilters();
  }

  void setProductCountFilter(String count) {
    _selectedProductCountFilter = count;
    applyAdvancedFilters();
  }

  void clearAllAdvancedFilters() {
    _selectedStatusFilter = 'All Statuses';
    _selectedDateRange = DateRange.all;
    _selectedPaymentMethod = 'All Methods';
    _selectedProductCountFilter = 'All Counts';
    _customDateRange = null;
    minAmountController.clear();
    maxAmountController.clear();
    _currentSort = SortOption.dateNewest;
    applyAdvancedFilters();
  }

  void applyAdvancedFilters() {
    filterOrders();
  }
}

// Add this enum for sort options
enum SortOption {
  dateNewest,
  dateOldest,
  overdueFirst,
  amountHighLow,    // ADD THIS
  amountLowHigh,    // ADD THIS
  customerAZ,       // ADD THIS
  customerZA,       // ADD THIS
}



// Extension to add copyWith method to OrdersModel
extension OrdersModelExtension on OrdersModel {
  OrdersModel copyWith({String? customerId}) {
    return OrdersModel(
      id: this.id,
      orderDate: this.orderDate,
      orderStatus: this.orderStatus,
      totalAmount: this.totalAmount,
      eligibilityForReturn: this.eligibilityForReturn,
      shipmentID: this.shipmentID,
        totalProduct: this.totalProduct,
        paymentCard: this.paymentCard
    );
  }
}
enum DateRange {
  all,
  today,
  yesterday,
  last7Days,
  last30Days,
  thisMonth,
  lastMonth,
  custom,
}