// admin_order_controller.dart (Updated with bulk selection)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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

  // Bulk update selected orders
  Future<Map<String, dynamic>> bulkUpdateOrders() async {
    final selectedOrderIds = _selectedOrders.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    int successCount = 0;
    int failCount = 0;
    List<String> errors = [];

    for (final orderId in selectedOrderIds) {
      final order = _orders.firstWhere((o) => o.id == orderId);
      final trackingNumber = getTrackingController(orderId).text.trim();

      if (trackingNumber.isEmpty) {
        errors.add('Order #${order.shortOrderId}: Missing tracking number');
        failCount++;
        continue;
      }

      try {
        // Update order status
        await _firestore
            .collection('users')
            .doc(order.customerId)
            .collection('order')
            .doc(orderId)
            .update({'orderStatus': 'to_receive'});

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
          'shippedDate': Timestamp.now(),
        };

        if (shipmentSnapshot.docs.isNotEmpty) {
          await shipmentSnapshot.docs.first.reference.update(shipmentData);
        } else {
          await shipmentRef.add(shipmentData);
        }

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
    };
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void filterOrders() {
    List<OrdersModel> filtered = _orders;

    // Filter by status
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

    // Filter by search
    if (searchController.text.isNotEmpty) {
      final search = searchController.text.toLowerCase();
      filtered = filtered.where((order) =>
      order.shortOrderId.toLowerCase().contains(search) ||
          (_customerNames[order.customerId] ?? '').toLowerCase().contains(search)
      ).toList();
    }

    // Filter overdue only if toggle is on
    if (_showOverdueOnly) {
      filtered = filtered.where((order) => isOrderOverdue(order)).toList();
    }

    // Apply sorting
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

      // Create cancellation document reference
      final cancellationRef = _firestore
          .collection('cancellation')
          .doc();

      // Prepare cancellation data
      final cancellationData = {
        'orderID': orderId,
        'cancelReason': cancellationReason,
        'cancelDate': FieldValue.serverTimestamp(),
        'cancelNote': cancelNote,
        'cancelledBy': 'admin', // Since this is from admin panel
      };

      // Use batch write for atomicity
      final batch = _firestore.batch();

      // Create cancellation document
      batch.set(cancellationRef, cancellationData);

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
    // Dispose all tracking controllers
    _trackingControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }
}

// Add this enum for sort options
enum SortOption {
  dateNewest,
  dateOldest,
  overdueFirst,
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
