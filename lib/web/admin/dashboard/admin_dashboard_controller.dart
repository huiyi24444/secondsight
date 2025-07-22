
// admin_dashboard_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';

import '../../../model/user_model.dart';

class AdminDashboardController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<DashboardStats> fetchDashboardStats({
    DateFilterType filterType = DateFilterType.day,
    DateTime? selectedDate,
  }) async {
    try {
      selectedDate ??= DateTime.now();

      // Calculate date range based on filter type
      DateTime startDate, endDate;
      DateTime previousStartDate, previousEndDate;

      switch (filterType) {
        case DateFilterType.day:
          startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          endDate = startDate.add(const Duration(days: 1));
          previousStartDate = startDate.subtract(const Duration(days: 1));
          previousEndDate = startDate;
          break;
        case DateFilterType.month:
          startDate = DateTime(selectedDate.year, selectedDate.month, 1);
          endDate = DateTime(selectedDate.year, selectedDate.month + 1, 1);
          previousStartDate = DateTime(selectedDate.year, selectedDate.month - 1, 1);
          previousEndDate = startDate;
          break;
        case DateFilterType.year:
          startDate = DateTime(selectedDate.year, 1, 1);
          endDate = DateTime(selectedDate.year + 1, 1, 1);
          previousStartDate = DateTime(selectedDate.year - 1, 1, 1);
          previousEndDate = startDate;
          break;
      }

      // Fetch orders for selected period
      final ordersQuery = await _firestore
          .collectionGroup('order')
          .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('orderDate', isLessThan: Timestamp.fromDate(endDate))
          .get();

      final List<OrdersModel> orders = ordersQuery.docs
          .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
          .toList();

      // Fetch orders for previous period (for comparison)
      final previousOrdersQuery = await _firestore
          .collectionGroup('order')
          .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(previousStartDate))
          .where('orderDate', isLessThan: Timestamp.fromDate(previousEndDate))
          .get();

      final List<OrdersModel> previousOrders = previousOrdersQuery.docs
          .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
          .toList();

      // Fetch today's orders for the indicator
      final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final todayOrdersQuery = await _firestore
          .collectionGroup('order')
          .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('orderDate', isLessThan: Timestamp.fromDate(todayEnd))
          .get();

      final todayOrders = todayOrdersQuery.docs.length;



      // Fetch customers
      final customersSnapshot = await _firestore.collection('users').get();
      final List<CustomerModel> customers = customersSnapshot.docs
          .map((doc) => CustomerModel.fromJson(doc.data(), doc.id))
          .toList();

      // Calculate stats for current period
      double revenue = orders
          .where((o) => o.orderStatus == 'completed')
          .fold(0.0, (sum, o) => sum + o.totalAmount);

      double previousRevenue = previousOrders
          .where((o) => o.orderStatus == 'completed')
          .fold(0.0, (sum, o) => sum + o.totalAmount);

      int completed = orders.where((o) => o.orderStatus == 'completed').length;
      int to_ship = orders.where((o) => o.orderStatus == 'to_ship' || o.orderStatus == 'to_ship').length;
      int to_receive = orders
          .where((o) => o.orderStatus == 'to_receive' )
          .length;
      int cancelled = orders.where((o) => o.orderStatus == 'cancelled').length;

      final toShipOrdersQuery = await _firestore
          .collectionGroup('order')
          .where('orderStatus', isEqualTo: 'to_ship')
          .get();
      final List<OrdersModel> allToShipOrders = toShipOrdersQuery.docs
          .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
          .toList();

      final overdue = allToShipOrders
          .where((order) {
        final orderDate = order.orderDate;
        final orderStartOfDay = DateTime(orderDate.year, orderDate.month, orderDate.day);
        final todayStartOfDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

        // Return true if the order date is before today
        return orderStartOfDay.isBefore(todayStartOfDay);
      })
          .length;
      // Calculate changes
      int revenueChange = revenue > 0 && previousRevenue > 0
          ? ((revenue - previousRevenue) / previousRevenue * 100).round()
          : 0;
      int orderChange = orders.isNotEmpty && previousOrders.isNotEmpty
          ? orders.length - previousOrders.length
          : 0;

      // Fetch recent orders (always show last 10 regardless of filter)
      final recentOrdersSnapshot = await FirebaseFirestore.instance
          .collectionGroup('order')
          .orderBy('orderDate', descending: true)
          .limit(10)
          .get();

      List<OrdersModel> recentOrders = recentOrdersSnapshot.docs
          .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
          .toList();

      // Count new orders (within last 24 hours)
      final last24Hours = DateTime.now().subtract(const Duration(hours: 24));
      final newOrdersCount = recentOrders
          .where((order) => order.orderDate.isAfter(last24Hours))
          .length;

      return DashboardStats(
        totalRevenue: revenue.toInt(),
        totalCustomers: customers.length,
        allOrders: orders.length,
        completedOrders: completed,
        to_ship_orders: to_ship,
        to_receive_orders: to_receive,
        cancelledOrders: cancelled,
        overdueOrders: overdue,
        recentOrders: recentOrders,
        rawOrderDocs: recentOrdersSnapshot.docs,
        todayOrders: todayOrders,
        revenueChange: revenueChange,
        orderChange: orderChange,
        customerChange: 0, // You can implement customer change logic if needed
        newOrdersCount: newOrdersCount,
      );
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      rethrow;
    }
  }

  Future<List<OrderProductModel>> fetchOrderProductsFromOrderDoc(DocumentSnapshot orderDoc) async {
    final userDocRef = orderDoc.reference.parent.parent;
    final orderId = orderDoc.id;

    if (userDocRef == null) {
      throw Exception("User document reference not found for order $orderId");
    }

    final orderProductsSnapshot = await userDocRef
        .collection('order')
        .doc(orderId)
        .collection('orderProducts')
        .get();

    return orderProductsSnapshot.docs
        .map((doc) => OrderProductModel.fromJson(doc.data()))
        .toList();
  }
}

class DashboardStats {
  final int totalRevenue;
  final int totalCustomers;
  final int allOrders;
  final int completedOrders;
  final int to_ship_orders;
  final int to_receive_orders;
  final int cancelledOrders;
  final int overdueOrders;
  final List<OrdersModel> recentOrders;
  final List<DocumentSnapshot> rawOrderDocs;
  final int todayOrders;
  final int revenueChange;
  final int orderChange;
  final int customerChange;
  //final int activeChange;
  final int newOrdersCount;

  DashboardStats({
    required this.totalRevenue,
    required this.totalCustomers,
    required this.allOrders,
    required this.completedOrders,
    required this.to_ship_orders,
    required this.to_receive_orders,
    required this.cancelledOrders,
    required this.overdueOrders,
    required this.recentOrders,
    required this.rawOrderDocs,
    required this.todayOrders,
    required this.revenueChange,
    required this.orderChange,
    required this.customerChange,
    //required this.activeChange,
    required this.newOrdersCount,
  });
}

// Define the enum here only once
enum DateFilterType { day, month, year }