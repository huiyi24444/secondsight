// Updated admin_dashboard_controller.dart with comparison logic
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../../model/user_model.dart';
import '../../../model/return_request_model.dart';

class AdminDashboardController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  Future<DashboardStats> fetchDashboardStats({
    DateFilterType filterType = DateFilterType.day,
    DateTime? selectedDate,
  }) async {
    try {
      selectedDate ??= DateTime.now();

      // Calculate date ranges for current and previous periods
      final dateRanges = _calculateDateRanges(filterType, selectedDate);
      final currentStart = dateRanges['currentStart']!;
      final currentEnd = dateRanges['currentEnd']!;
      final previousStart = dateRanges['previousStart']!;
      final previousEnd = dateRanges['previousEnd']!;

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

      // ADD IT HERE - Fetch return requests with pending statuses
      final returnRequestsData = await _fetchPendingReturnRequests();
      // Fetch orders for CURRENT period
      Query currentOrdersQuery = _firestore.collectionGroup('order');
      if (filterType != DateFilterType.all) {
        currentOrdersQuery = currentOrdersQuery
            .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(currentStart))
            .where('orderDate', isLessThan: Timestamp.fromDate(currentEnd));
      }

      final currentOrdersSnapshot = await currentOrdersQuery.get();
      final List<OrdersModel> currentOrders = currentOrdersSnapshot.docs
          .map((doc) => OrdersModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Fetch orders for PREVIOUS period (for comparison)
      List<OrdersModel> previousOrders = [];
      if (filterType != DateFilterType.all) {
        final previousOrdersQuery = _firestore
            .collectionGroup('order')
            .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(previousStart))
            .where('orderDate', isLessThan: Timestamp.fromDate(previousEnd));

        final previousOrdersSnapshot = await previousOrdersQuery.get();
        previousOrders = previousOrdersSnapshot.docs
            .map((doc) => OrdersModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      }

      // Calculate today's activity (always show today regardless of filter)
      final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final todayActivity = await _fetchTodayActivity(todayStart, todayEnd);

      // Calculate overdue orders
      final List<OrdersModel> allToShipOrders = activeToShipQuery.docs
          .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
          .toList();
      int overdue = _calculateOverdueOrders(allToShipOrders);

      // Fetch customers for current period
      Query currentCustomersQuery = _firestore.collection('users');
      if (filterType != DateFilterType.all) {
        currentCustomersQuery = currentCustomersQuery
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(currentStart))
            .where('createdAt', isLessThan: Timestamp.fromDate(currentEnd));
      }
      final currentCustomersSnapshot = await currentCustomersQuery.get();
      final currentCustomerCount = currentCustomersSnapshot.docs.length;

      // Fetch customers for previous period (for comparison)
      int previousCustomerCount = 0;
      if (filterType != DateFilterType.all) {
        final previousCustomersQuery = _firestore
            .collection('users')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(previousStart))
            .where('createdAt', isLessThan: Timestamp.fromDate(previousEnd));
        final previousCustomersSnapshot = await previousCustomersQuery.get();
        previousCustomerCount = previousCustomersSnapshot.docs.length;
      }

      // Get total customers (for display)
      final allCustomersSnapshot = await _firestore.collection('users').get();
      final totalCustomers = allCustomersSnapshot.docs.length;

      // Calculate revenue for CURRENT period (only from completed orders)
      double currentRevenue = currentOrders
          .where((o) => o.orderStatus == 'completed')
          .fold(0.0, (sum, o) => sum + o.totalAmount);

      // Calculate revenue for PREVIOUS period
      double previousRevenue = previousOrders
          .where((o) => o.orderStatus == 'completed')
          .fold(0.0, (sum, o) => sum + o.totalAmount);

      // Calculate period-specific status counts
      int currentCompleted = currentOrders.where((o) => o.orderStatus == 'completed').length;
      int currentCancelled = currentOrders.where((o) => o.orderStatus == 'cancelled').length;

      // Calculate changes
      int orderChange = _calculatePercentageChange(currentOrders.length, previousOrders.length);
      int revenueChange = _calculatePercentageChange(currentRevenue, previousRevenue);
      int customerChange = _calculatePercentageChange(currentCustomerCount, previousCustomerCount);

      // Calculate performance metrics
      final performanceMetrics = await _calculatePerformanceMetrics();

      // Fetch recent orders
      final recentOrdersSnapshot = await _firestore
          .collectionGroup('order')
          .orderBy('orderDate', descending: true)
          .limit(10)
          .get();

      List<OrdersModel> recentOrders = recentOrdersSnapshot.docs
          .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
          .toList();

      // Count new orders (last 24 hours)
      final last24Hours = DateTime.now().subtract(const Duration(hours: 24));
      final newOrdersCount = recentOrders
          .where((order) => order.orderDate.isAfter(last24Hours))
          .length;

      return DashboardStats(
        // Business metrics (filtered by date)
        totalRevenue: currentRevenue.toInt(),
        allOrders: currentOrders.length,
        completedOrders: currentCompleted,
        cancelledOrders: currentCancelled,

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

        // Changes (now properly calculated)
        orderChange: orderChange,
        revenueChange: revenueChange,
        customerChange: customerChange,

        // Legacy fields (keeping for compatibility)
        to_ship_orders: activeToShip,
        to_receive_orders: activeToReceive,
        todayOrders: todayActivity['created'] ?? 0,

      );
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      rethrow;
    }


  }

  Map<String, DateTime> _calculateDateRanges(DateFilterType filterType, DateTime selectedDate) {
    DateTime currentStart, currentEnd, previousStart, previousEnd;

    switch (filterType) {
      case DateFilterType.day:
      // Current day
        currentStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        currentEnd = currentStart.add(const Duration(days: 1));
        // Previous day
        previousStart = currentStart.subtract(const Duration(days: 1));
        previousEnd = currentStart;
        break;

      case DateFilterType.month:
      // Current month
        currentStart = DateTime(selectedDate.year, selectedDate.month, 1);
        currentEnd = DateTime(selectedDate.year, selectedDate.month + 1, 1);
        // Previous month
        final prevMonth = selectedDate.month == 1 ? 12 : selectedDate.month - 1;
        final prevYear = selectedDate.month == 1 ? selectedDate.year - 1 : selectedDate.year;
        previousStart = DateTime(prevYear, prevMonth, 1);
        previousEnd = currentStart;
        break;

      case DateFilterType.year:
      // Current year
        currentStart = DateTime(selectedDate.year, 1, 1);
        currentEnd = DateTime(selectedDate.year + 1, 1, 1);
        // Previous year
        previousStart = DateTime(selectedDate.year - 1, 1, 1);
        previousEnd = currentStart;
        break;

      case DateFilterType.all:
      // All time - no comparison needed
        currentStart = DateTime(2020, 1, 1); // Or your business start date
        currentEnd = DateTime.now().add(const Duration(days: 1));
        previousStart = currentStart;
        previousEnd = currentStart;
        break;
    }

    return {
      'currentStart': currentStart,
      'currentEnd': currentEnd,
      'previousStart': previousStart,
      'previousEnd': previousEnd,
    };
  }

  int _calculatePercentageChange(num currentValue, num previousValue) {
    if (previousValue == 0) {
      // If previous value is 0, return 100% if current > 0, else 0%
      return currentValue > 0 ? 100 : 0;
    }

    // Calculate percentage change
    double change = ((currentValue - previousValue) / previousValue) * 100;

    // Round to nearest integer
    return change.round();
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

    try {
      // Get recent orders with various statuses for comprehensive analysis
      final recentOrdersQuery = await _firestore
          .collectionGroup('order')
          .orderBy('orderDate', descending: true)
          .limit(200) // Increased sample size for better accuracy
          .get();

      final allRecentOrders = recentOrdersQuery.docs
          .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
          .toList();

      if (allRecentOrders.isEmpty) {
        return {
          'avgProcessingHours': 0,
          'avgShippingHours': 'No data',        // Changed from 0
          'fulfillmentRate': 'No data',         // Changed from 0
          'avgCompletionHours': 'No data',      // Added this line
          'processingEfficiency': 0,
          'cancellationRate': 0,
        };
      }
      // Calculate average processing time (order creation to shipping)
      double totalProcessingHours = 0;
      int processedOrdersCount = 0;

      for (final order in allRecentOrders) {
        // Only calculate for orders that have been shipped (have toShipDate or toReceiveDate)
        if (order.toShipDate != null) {
          final processingTime = order.toShipDate!.difference(order.orderDate).inHours;
          if (processingTime >= 0) { // Ensure valid time difference
            totalProcessingHours += processingTime;
            processedOrdersCount++;
          }
        } else if (order.toReceiveDate != null) {
          // If toShipDate is missing but toReceiveDate exists, estimate processing time
          // This handles cases where toShipDate wasn't properly recorded
          final processingTime = order.toReceiveDate!.difference(order.orderDate).inHours;
          if (processingTime >= 0) {
            // Assume 12 hours of shipping time, so processing = total - 12
            totalProcessingHours += (processingTime - 12).clamp(0, double.infinity);
            processedOrdersCount++;
          }
        }
      }

      metrics['avgProcessingHours'] = processedOrdersCount > 0
          ? (totalProcessingHours / processedOrdersCount).round()
          : 0;

      // Calculate average shipping time (shipping to delivery)
      double totalShippingHours = 0;
      int shippedOrdersCount = 0;

      for (final order in allRecentOrders) {
        DateTime? shippingStartDate;
        DateTime? deliveryDate;

        // Determine shipping start date (priority: toReceiveDate > toShipDate)
        if (order.toReceiveDate != null) {
          shippingStartDate = order.toReceiveDate;
        } else if (order.toShipDate != null) {
          shippingStartDate = order.toShipDate;
        }

        // Determine delivery date
        if (order.completedDate != null) {
          deliveryDate = order.completedDate;
        }

        // Calculate shipping time if both dates are available
        if (shippingStartDate != null && deliveryDate != null) {
          final shippingTime = deliveryDate.difference(shippingStartDate).inHours;
          if (shippingTime >= 0) { // Ensure valid time difference
            totalShippingHours += shippingTime;
            shippedOrdersCount++;
          }
        }
      }

      metrics['avgShippingHours'] = shippedOrdersCount > 0
          ? (totalShippingHours / shippedOrdersCount).round()
          : 'No data';  // Changed from : 0

      // Calculate fulfillment rate (completed orders / total orders)
      final completedOrdersCount = allRecentOrders
          .where((order) => order.orderStatus == 'completed')
          .length;

      final nonCancelledOrdersCount = allRecentOrders
          .where((order) => order.orderStatus != 'cancelled')
          .length;

      // Use non-cancelled orders as the base for fulfillment rate calculation
      metrics['fulfillmentRate'] = nonCancelledOrdersCount > 0
          ? ((completedOrdersCount / nonCancelledOrdersCount) * 100).round()
          : 'No data';  // Changed from : 0


      // Additional performance metrics

      // Calculate average order completion time (order creation to completion)
      double totalCompletionHours = 0;
      int completedOrdersForTime = 0;

      for (final order in allRecentOrders) {
        if (order.orderStatus == 'completed' && order.completedDate != null) {
          final completionTime = order.completedDate!.difference(order.orderDate).inHours;
          if (completionTime >= 0) {
            totalCompletionHours += completionTime;
            completedOrdersForTime++;
          }
        }
      }

      metrics['avgCompletionHours'] = completedOrdersForTime > 0
          ? (totalCompletionHours / completedOrdersForTime).round()
          : 'No data';  // Changed from : 0

      // Calculate order processing efficiency (orders processed within 24 hours)
      final ordersProcessedWithin24h = allRecentOrders.where((order) {
        if (order.toShipDate == null) return false;
        final processingTime = order.toShipDate!.difference(order.orderDate).inHours;
        return processingTime <= 24 && processingTime >= 0;
      }).length;

      final totalProcessableOrders = allRecentOrders
          .where((order) => order.toShipDate != null || order.orderStatus == 'to_ship')
          .length;

      metrics['processingEfficiency'] = totalProcessableOrders > 0
          ? ((ordersProcessedWithin24h / totalProcessableOrders) * 100).round()
          : 0;

      // Calculate cancellation rate
      final cancelledOrdersCount = allRecentOrders
          .where((order) => order.orderStatus == 'cancelled')
          .length;

      metrics['cancellationRate'] = allRecentOrders.isNotEmpty
          ? ((cancelledOrdersCount / allRecentOrders.length) * 100).round()
          : 0;

    } catch (e) {
      print('Error calculating performance metrics: $e');
      // Return default values on error
      return {
        'avgProcessingHours': 0,
        'avgShippingHours': 0,
        'fulfillmentRate': 0,
        'avgCompletionHours': 0,
        'processingEfficiency': 0,
        'cancellationRate': 0,
      };
    }

    return metrics;
  }
  // Keep the existing method for updating order status
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

  Future<ReturnRequestsData> _fetchPendingReturnRequests() async {
    // Fetch return requests with pending_approval status
    final pendingApprovalQuery = await _firestore
        .collectionGroup('returnRequests')
        .where('returnStatus', isEqualTo: 'pending_approval')
        .get();

    // Fetch return requests with pending_inspection status
    final pendingInspectionQuery = await _firestore
        .collectionGroup('returnRequests')
        .where('returnStatus', isEqualTo: 'pending_inspection')
        .get();

    final pendingApprovalReturns = pendingApprovalQuery.docs
        .map((doc) => ReturnRequestModel.fromDocument(doc))
        .toList();

    final pendingInspectionReturns = pendingInspectionQuery.docs
        .map((doc) => ReturnRequestModel.fromDocument(doc))
        .toList();

    return ReturnRequestsData(
      pendingApprovalCount: pendingApprovalReturns.length,
      pendingInspectionCount: pendingInspectionReturns.length,
      pendingApprovalReturns: pendingApprovalReturns,
      pendingInspectionReturns: pendingInspectionReturns,
    );
  }



}

// DashboardStats class remains the same
class DashboardStats {
  final int totalRevenue;
  final int totalCustomers;
  final int allOrders;
  final int completedOrders;
  final int to_ship_orders; // Legacy - same as activeToShipOrders
  final int to_receive_orders; // Legacy - same as activeToReceiveOrders
  final int cancelledOrders;
  final int overdueOrders;
  final List<OrdersModel> recentOrders;
  final List<DocumentSnapshot> rawOrderDocs;
  final int todayOrders;
  final int revenueChange;
  final int orderChange;
  final int customerChange;
  final int newOrdersCount;

  final int pendingApprovalReturns;
  final int pendingInspectionReturns;
  final int pendingReturnRequests;
  final List<ReturnRequestModel> recentReturnRequests;

  // Simplified new fields
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

    this.pendingApprovalReturns = 0,
    this.pendingInspectionReturns = 0,
    this.pendingReturnRequests = 0,
    this.recentReturnRequests = const [],

    this.activeToShipOrders = 0,
    this.activeToReceiveOrders = 0,
    this.statusActivity = const {},
    this.performanceMetrics = const {},
  });
}

class ReturnRequestsData {
  final int pendingApprovalCount;
  final int pendingInspectionCount;
  final List<ReturnRequestModel> pendingApprovalReturns;
  final List<ReturnRequestModel> pendingInspectionReturns;

  ReturnRequestsData({
    required this.pendingApprovalCount,
    required this.pendingInspectionCount,
    required this.pendingApprovalReturns,
    required this.pendingInspectionReturns,
  });
}

// Simplified enum - removed StatusDateFilterType
enum DateFilterType { day, month, year, all }