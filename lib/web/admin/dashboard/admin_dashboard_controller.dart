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
    StatusDateFilterType statusFilter = StatusDateFilterType.created,
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
        case DateFilterType.all:
        // Fetch all orders regardless of date
          startDate = DateTime(2020, 1, 1); // Or your business start date
          endDate = DateTime.now().add(const Duration(days: 1));
          // For comparison, use last 30 days
          previousEndDate = DateTime.now().subtract(const Duration(days: 30));
          previousStartDate = previousEndDate.subtract(const Duration(days: 30));
          break;
      }

      // Determine which date field to query based on status filter
      String dateField = _getDateFieldForStatusFilter(statusFilter);

      // Fetch ALL orders for current status counts (regardless of date)
      final allActiveOrdersQuery = await _firestore
          .collectionGroup('order')
          .where('orderStatus', whereIn: ['to_ship', 'to_receive'])
          .get();

      final List<OrdersModel> allActiveOrders = allActiveOrdersQuery.docs
          .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
          .toList();

      // Calculate current active status counts
      int activeToShip = allActiveOrders.where((o) => o.orderStatus == 'to_ship').length;
      int activeToReceive = allActiveOrders.where((o) => o.orderStatus == 'to_receive').length;

      // Fetch orders for selected period based on the chosen date field
      Query ordersQuery = _firestore.collectionGroup('order');

      if (filterType != DateFilterType.all) {
        ordersQuery = ordersQuery
            .where(dateField, isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where(dateField, isLessThan: Timestamp.fromDate(endDate));
      }

      final ordersSnapshot = await ordersQuery.get();
      final List<OrdersModel> orders = ordersSnapshot.docs
          .map((doc) => OrdersModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Fetch status-specific activity for the period
      final statusActivityStats = await _fetchStatusActivityStats(startDate, endDate);

      // Calculate overdue orders with enhanced logic
      int overdue = await _calculateOverdueOrders(allActiveOrders);

      // Fetch customers
      final customersSnapshot = await _firestore.collection('users').get();
      final List<CustomerModel> customers = customersSnapshot.docs
          .map((doc) => CustomerModel.fromJson(doc.data(), doc.id))
          .toList();

      // Calculate revenue (only from completed orders in the period)
      double revenue = orders
          .where((o) => o.orderStatus == 'completed')
          .fold(0.0, (sum, o) => sum + o.totalAmount);

      // Calculate period-specific status counts
      int periodToShip = orders.where((o) => o.orderStatus == 'to_ship').length;
      int periodToReceive = orders.where((o) => o.orderStatus == 'to_receive').length;
      int periodCompleted = orders.where((o) => o.orderStatus == 'completed').length;
      int periodCancelled = orders.where((o) => o.orderStatus == 'cancelled').length;

      // Fetch recent orders
      final recentOrdersSnapshot = await _firestore
          .collectionGroup('order')
          .orderBy('orderDate', descending: true)
          .limit(10)
          .get();

      List<OrdersModel> recentOrders = recentOrdersSnapshot.docs
          .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
          .toList();

      // Count new orders
      final last24Hours = DateTime.now().subtract(const Duration(hours: 24));
      final newOrdersCount = recentOrders
          .where((order) => order.orderDate.isAfter(last24Hours))
          .length;

      // Calculate performance metrics
      final performanceMetrics = await _calculatePerformanceMetrics(orders);

      return DashboardStats(
        totalRevenue: revenue.toInt(),
        totalCustomers: customers.length,
        allOrders: orders.length,
        completedOrders: periodCompleted,
        to_ship_orders: periodToShip,
        to_receive_orders: periodToReceive,
        cancelledOrders: periodCancelled,
        overdueOrders: overdue,
        recentOrders: recentOrders,
        rawOrderDocs: recentOrdersSnapshot.docs,
        todayOrders: statusActivityStats['created'] ?? 0,
        revenueChange: 0, // Calculate based on your needs
        orderChange: 0, // Calculate based on your needs
        customerChange: 0,
        newOrdersCount: newOrdersCount,
        // New fields for enhanced tracking
        activeToShipOrders: activeToShip,
        activeToReceiveOrders: activeToReceive,
        statusActivity: statusActivityStats,
        performanceMetrics: performanceMetrics,
      );
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      rethrow;
    }
  }

  String _getDateFieldForStatusFilter(StatusDateFilterType filter) {
    switch (filter) {
      case StatusDateFilterType.created:
        return 'orderDate';
      case StatusDateFilterType.shipped:
        return 'toReceiveDate';
      case StatusDateFilterType.completed:
        return 'completedDate';
      case StatusDateFilterType.statusChanged:
        return 'lastStatusUpdate';
    }
  }

  Future<Map<String, int>> _fetchStatusActivityStats(DateTime startDate, DateTime endDate) async {
    final stats = <String, int>{};

    // Orders created in period
    final createdQuery = await _firestore
        .collectionGroup('order')
        .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('orderDate', isLessThan: Timestamp.fromDate(endDate))
        .get();
    stats['created'] = createdQuery.docs.length;

    // Orders moved to ship in period
    final toShipQuery = await _firestore
        .collectionGroup('order')
        .where('toShipDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('toShipDate', isLessThan: Timestamp.fromDate(endDate))
        .get();
    stats['movedToShip'] = toShipQuery.docs.length;

    // Orders shipped in period
    final shippedQuery = await _firestore
        .collectionGroup('order')
        .where('toReceiveDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('toReceiveDate', isLessThan: Timestamp.fromDate(endDate))
        .get();
    stats['shipped'] = shippedQuery.docs.length;

    // Orders completed in period
    final completedQuery = await _firestore
        .collectionGroup('order')
        .where('completedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('completedDate', isLessThan: Timestamp.fromDate(endDate))
        .get();
    stats['completed'] = completedQuery.docs.length;

    return stats;
  }

  Future<int> _calculateOverdueOrders(List<OrdersModel> activeOrders) async {
    int overdue = 0;
    final now = DateTime.now();

    for (final order in activeOrders) {
      if (order.orderStatus == 'to_ship') {
        // Use the toShipDate if available, otherwise fall back to orderDate
        final referenceDate = order.toShipDate ?? order.orderDate;
        final daysSinceStatus = now.difference(referenceDate).inDays;

        // Consider overdue if more than 2 days in to_ship status
        if (daysSinceStatus > 2) {
          overdue++;
        }
      }
    }

    return overdue;
  }

  Future<Map<String, dynamic>> _calculatePerformanceMetrics(List<OrdersModel> orders) async {
    final metrics = <String, dynamic>{};

    // Calculate average processing time (order to ship)
    final processedOrders = orders.where((o) => o.toShipDate != null).toList();
    if (processedOrders.isNotEmpty) {
      final totalProcessingHours = processedOrders.fold<int>(
        0,
            (sum, order) => sum + order.toShipDate!.difference(order.orderDate).inHours,
      );
      metrics['avgProcessingHours'] = (totalProcessingHours / processedOrders.length).round();
    }

    // Calculate average shipping time (ship to delivery)
    final deliveredOrders = orders.where((o) =>
    o.toShipDate != null && o.completedDate != null
    ).toList();
    if (deliveredOrders.isNotEmpty) {
      final totalShippingHours = deliveredOrders.fold<int>(
        0,
            (sum, order) => sum + order.completedDate!.difference(order.toShipDate!).inHours,
      );
      metrics['avgShippingHours'] = (totalShippingHours / deliveredOrders.length).round();
    }

    // Calculate fulfillment rate
    final totalOrders = orders.length;
    final completedOrders = orders.where((o) => o.orderStatus == 'completed').length;
    if (totalOrders > 0) {
      metrics['fulfillmentRate'] = ((completedOrders / totalOrders) * 100).round();
    }

    return metrics;
  }

  // Method to update order status with date tracking
  Future<void> updateOrderStatus({
    required String userId,
    required String orderId,
    required String newStatus,
    required String adminId,
  }) async {
    final now = DateTime.now();
    final updateData = <String, dynamic>{
      'orderStatus': newStatus,
      'lastStatusUpdate': Timestamp.fromDate(now),
      'lastUpdatedBy': adminId,
    };

    // Add specific date field based on new status
    switch (newStatus) {
      case 'confirmed':
        updateData['confirmedDate'] = Timestamp.fromDate(now);
        break;
      case 'to_ship':
        updateData['toShipDate'] = Timestamp.fromDate(now);
        break;
      case 'to_receive':
        updateData['toReceiveDate'] = Timestamp.fromDate(now);
        break;
      case 'completed':
        updateData['completedDate'] = Timestamp.fromDate(now);
        break;
      case 'cancelled':
        updateData['cancelledDate'] = Timestamp.fromDate(now);
        break;
    }

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('order')
        .doc(orderId)
        .update(updateData);
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

// Enhanced DashboardStats class
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
  final int newOrdersCount;

  // New fields for enhanced tracking
  final int activeToShipOrders;
  final int activeToReceiveOrders;
  final Map<String, int> statusActivity;
  final Map<String, dynamic> performanceMetrics;

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
    required this.newOrdersCount,
    this.activeToShipOrders = 0,
    this.activeToReceiveOrders = 0,
    this.statusActivity = const {},
    this.performanceMetrics = const {},
  });
}

// Enhanced enums
enum DateFilterType { day, month, year, all }
enum StatusDateFilterType { created, shipped, completed, statusChanged }