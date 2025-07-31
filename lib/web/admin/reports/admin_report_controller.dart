import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../model/order_model.dart';
import '../dashboard/admin_dashboard_controller.dart';

class AdminReportController {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch all orders and attach userId (customerId)
  static Future<List<OrdersModel>> fetchAllOrders() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collectionGroup('order') // searches all users' orders
        .get();

    return querySnapshot.docs.map((doc) {
      final userId = doc.reference.parent.parent!.id;
      return OrdersModel.fromJson(doc.data(), doc.id).copyWith(customerId: userId);
    }).toList();
  }

  /// Count orderProducts for a given user and order
  static Future<int> fetchOrderProductCount(String userId, String orderId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('order')
        .doc(orderId)
        .collection('orderProducts')
        .get();

    return snapshot.docs.length;
  }

  /// Map of orderId → item count
  static Future<Map<String, int>> getOrderItemCounts(List<OrdersModel> orders) async {
    final Map<String, int> orderItemCounts = {};

    for (final order in orders) {
      final String userId = order.customerId ?? '';
      final String orderId = order.id;

      final count = await fetchOrderProductCount(userId, orderId);
      orderItemCounts[orderId] = count;
    }

    return orderItemCounts;
  }

  Future<DashboardStats> fetchDashboardStats({
    DateFilterType filterType = DateFilterType.day,
    DateTime? selectedDate,
  }) async {
    try {
      selectedDate ??= DateTime.now();

      // Calculate date range based on filter type
      DateTime startDate, endDate;

      switch (filterType) {
        case DateFilterType.day:
          startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          endDate = startDate.add(const Duration(days: 1));
          break;
        case DateFilterType.month:
          startDate = DateTime(selectedDate.year, selectedDate.month, 1);
          endDate = DateTime(selectedDate.year, selectedDate.month + 1, 1);
          break;
        case DateFilterType.year:
          startDate = DateTime(selectedDate.year, 1, 1);
          endDate = DateTime(selectedDate.year + 1, 1, 1);
          break;
        case DateFilterType.all:
          startDate = DateTime(2020, 1, 1); // Or your business start date
          endDate = DateTime.now().add(const Duration(days: 1));
          break;
      }

      // ALWAYS fetch active orders for operational status
      final activeToShipQuery = await _firestore
          .collectionGroup('order')
          .where('orderStatus', isEqualTo: 'to_ship')
          .get();

      final activeToReceiveQuery = await _firestore
          .collectionGroup('order')
          .where('orderStatus', isEqualTo: 'to_receive')
          .get();

      int activeToShip = activeToShipQuery.docs.length;
      int activeToReceive = activeToReceiveQuery.docs.length;

      // Fetch orders for selected period (for business metrics)
      Query ordersQuery = _firestore.collectionGroup('order');

      if (filterType != DateFilterType.all) {
        ordersQuery = ordersQuery
            .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('orderDate', isLessThan: Timestamp.fromDate(endDate));
      }

      final ordersSnapshot = await ordersQuery.get();
      final List<OrdersModel> orders = ordersSnapshot.docs.map((doc) {
        final userId = doc.reference.parent.parent?.id ?? '';
        return OrdersModel.fromJson(doc.data() as Map<String, dynamic>, doc.id).copyWith(customerId: userId);
      }).toList();

      // Calculate today's activity (always show today regardless of filter)
      final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final todayActivity = await _fetchTodayActivity(todayStart, todayEnd);

      // Calculate overdue orders
      final List<OrdersModel> allToShipOrders = activeToShipQuery.docs
          .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
          .toList();

      int overdue = _calculateOverdueOrders(allToShipOrders);

      // Fetch customers
      final customersSnapshot = await _firestore.collection('users').get();
      final totalCustomers = customersSnapshot.docs.length;

      // Calculate revenue (only from completed orders in period)
      double revenue = orders
          .where((o) => o.orderStatus == 'completed')
          .fold(0.0, (sum, o) => sum + o.totalAmount);

      // Calculate period-specific status counts
      int periodCompleted = orders.where((o) => o.orderStatus == 'completed').length;
      int periodCancelled = orders.where((o) => o.orderStatus == 'cancelled').length;

      // Calculate performance metrics
      final performanceMetrics = await _calculatePerformanceMetrics();

      // Fetch recent orders
      final recentOrdersSnapshot = await _firestore
          .collectionGroup('order')
          .orderBy('orderDate', descending: true)
          .limit(10)
          .get();

      List<OrdersModel> recentOrders = recentOrdersSnapshot.docs.map((doc) {
        final userId = doc.reference.parent.parent?.id ?? '';
        return OrdersModel.fromJson(doc.data(), doc.id).copyWith(customerId: userId);
      }).toList();

      // Count new orders (last 24 hours)
      final last24Hours = DateTime.now().subtract(const Duration(hours: 24));
      final newOrdersCount = recentOrders
          .where((order) => order.orderDate.isAfter(last24Hours))
          .length;

      // Simple change calculations for display
      int orderChange = 0;
      int revenueChange = 0;

      // You can implement proper comparison logic here if needed
      // For now, keeping it simple

      return DashboardStats(
        // Business metrics (filtered by date)
        totalRevenue: revenue.toInt(),
        allOrders: orders.length,
        completedOrders: periodCompleted,
        cancelledOrders: periodCancelled,

        // Operational status (always current)
        activeToShipOrders: activeToShip,
        activeToReceiveOrders: activeToReceive,

        // Activity (always today)
        statusActivity: todayActivity,

        // Performance (overall)
        performanceMetrics: performanceMetrics,

        // Other stats
        overdueOrders: overdue,
        totalCustomers: totalCustomers,
        recentOrders: recentOrders,
        rawOrderDocs: recentOrdersSnapshot.docs,
        newOrdersCount: newOrdersCount,

        // Changes
        orderChange: orderChange,
        revenueChange: revenueChange,

        // Legacy fields (keeping for compatibility)
        to_ship_orders: activeToShip,
        to_receive_orders: activeToReceive,
        todayOrders: todayActivity['created'] ?? 0,
        customerChange: 0,
      );
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> _fetchTodayActivity(DateTime startDate, DateTime endDate) async {
    final stats = <String, int>{};

    // Orders created today
    final createdQuery = await _firestore
        .collectionGroup('order')
        .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('orderDate', isLessThan: Timestamp.fromDate(endDate))
        .get();
    stats['created'] = createdQuery.docs.length;

    // Orders shipped today (if you have toReceiveDate field)
    try {
      final shippedQuery = await _firestore
          .collectionGroup('order')
          .where('toReceiveDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('toReceiveDate', isLessThan: Timestamp.fromDate(endDate))
          .get();
      stats['shipped'] = shippedQuery.docs.length;
    } catch (e) {
      // If field doesn't exist yet, default to 0
      stats['shipped'] = 0;
    }

    // Orders completed today (if you have completedDate field)
    try {
      final completedQuery = await _firestore
          .collectionGroup('order')
          .where('completedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('completedDate', isLessThan: Timestamp.fromDate(endDate))
          .get();
      stats['completed'] = completedQuery.docs.length;
    } catch (e) {
      // If field doesn't exist yet, default to 0
      stats['completed'] = 0;
    }

    return stats;
  }
  int _calculateOverdueOrders(List<OrdersModel> toShipOrders) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return toShipOrders.where((order) {
      final orderDateOnly = DateTime(
        order.orderDate.year,
        order.orderDate.month,
        order.orderDate.day,
      );
      // Order is overdue if it's in 'to_ship' status and not from today
      return orderDateOnly.isBefore(todayStart);
    }).length;
  }
  Future<Map<String, dynamic>> _calculatePerformanceMetrics() async {
    final metrics = <String, dynamic>{};

    // Get a sample of recent completed orders for performance calculation
    final recentCompletedOrders = await _firestore
        .collectionGroup('order')
        .where('orderStatus', isEqualTo: 'completed')
        .orderBy('orderDate', descending: true)
        .limit(100) // Sample size
        .get();

    final completedOrders = recentCompletedOrders.docs
        .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
        .toList();

    if (completedOrders.isNotEmpty) {
      // Calculate average processing time (if date fields exist)
      int totalProcessingHours = 0;
      int processedCount = 0;

      for (final order in completedOrders) {
        // For now, estimate based on order date
        // In real implementation with status dates, use: order.toShipDate - order.orderDate
        if (order.toShipDate != null) {
          totalProcessingHours += order.toShipDate!.difference(order.orderDate).inHours;
          processedCount++;
        } else {
          // Estimate: assume 24 hours processing time
          totalProcessingHours += 24;
          processedCount++;
        }
      }

      if (processedCount > 0) {
        metrics['avgProcessingHours'] = (totalProcessingHours / processedCount).round();
      } else {
        metrics['avgProcessingHours'] = 24; // Default
      }

      // Calculate average shipping time
      // For now, estimate. With full implementation, use: completedDate - toReceiveDate
      metrics['avgShippingHours'] = 72; // 3 days estimate

      // Calculate fulfillment rate
      final totalOrders = await _firestore
          .collectionGroup('order')
          .get();

      final completedCount = await _firestore
          .collectionGroup('order')
          .where('orderStatus', isEqualTo: 'completed')
          .get();

      if (totalOrders.docs.isNotEmpty) {
        metrics['fulfillmentRate'] =
            ((completedCount.docs.length / totalOrders.docs.length) * 100).round();
      } else {
        metrics['fulfillmentRate'] = 0;
      }
    } else {
      // Default values if no data
      metrics['avgProcessingHours'] = 0;
      metrics['avgShippingHours'] = 0;
      metrics['fulfillmentRate'] = 0;
    }

    return metrics;
  }

  Future<List<OrdersModel>> fetchToReceiveOrders() async {
    final querySnapshot = await _firestore
        .collectionGroup('order') // Searches all 'order' subcollections
        .where('orderStatus', isEqualTo: 'to_receive')
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      return OrdersModel.fromDocument(doc); // Ensure you pass the doc
    }).toList();
  }
}
