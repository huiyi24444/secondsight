// lib/controller/admin/order_management_controller.dart

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
  Set<String> _expandedOrders = {};

  bool _isLoading = true;
  String _selectedTab = 'All';
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  // Getters
  List<OrdersModel> get orders => _orders;
  List<OrdersModel> get filteredOrders => _filteredOrders;
  Map<String, List<OrderProductModel>> get orderProducts => _orderProducts;
  Map<String, Map<String, dynamic>> get productDetails => _productDetails;
  Map<String, String> get customerNames => _customerNames;
  Set<String> get expandedOrders => _expandedOrders;
  bool get isLoading => _isLoading;
  String get selectedTab => _selectedTab;
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;

  // Computed properties
  int get totalPages => (_filteredOrders.length / _itemsPerPage).ceil();
  int get startIndex => (_currentPage - 1) * _itemsPerPage;
  int get endIndex => startIndex + _itemsPerPage;

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

      loadedOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate)); // Sort newest to oldest
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
          order.shortOrderId.toLowerCase().contains(search)
      ).toList();
    }

    _filteredOrders = filtered;
    _currentPage = 1;
    notifyListeners();
  }

  void setSelectedTab(String tab) {
    _selectedTab = tab;
    filterOrders();
  }

  void setCurrentPage(int page) {
    _currentPage = page;
    notifyListeners();
  }

  void toggleOrderExpansion(String orderId) {
    if (_expandedOrders.contains(orderId)) {
      _expandedOrders.remove(orderId);
    } else {
      _expandedOrders.add(orderId);
    }
    notifyListeners();
  }

  bool isOrderExpanded(String orderId) {
    return _expandedOrders.contains(orderId);
  }

  Future<void> updateOrderStatus(OrdersModel order, String newStatus) async {
    try {
      // Find the user document that contains this order
      final usersSnapshot = await _firestore.collection('users').get();

      for (final userDoc in usersSnapshot.docs) {
        final orderDoc = await userDoc.reference.collection('order').doc(order.id).get();
        if (orderDoc.exists) {
          await orderDoc.reference.update({'orderStatus': newStatus});
          break;
        }
      }

      // Reload orders to reflect changes
      await loadOrders();
    } catch (e) {
      print('Error updating order status: $e');
    }
  }

  Future<void> deleteOrder(OrdersModel order) async {
    try {
      // Find the user document that contains this order
      final usersSnapshot = await _firestore.collection('users').get();

      for (final userDoc in usersSnapshot.docs) {
        final orderDoc = await userDoc.reference.collection('order').doc(order.id).get();
        if (orderDoc.exists) {
          // Delete order products first
          final orderProductsSnapshot = await orderDoc.reference.collection('orderProducts').get();
          for (final productDoc in orderProductsSnapshot.docs) {
            await productDoc.reference.delete();
          }

          // Then delete the order
          await orderDoc.reference.delete();
          break;
        }
      }

      // Reload orders to reflect changes
      await loadOrders();
    } catch (e) {
      print('Error deleting order: $e');
    }
  }

  String formatDate(DateTime date) {
    final formatter = DateFormat('d MMM yyyy | h:mm a');
    return formatter.format(date);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }
}