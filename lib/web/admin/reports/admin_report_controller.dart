import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

      // Use the same date range calculation logic from admin_dashboard_controller
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

      // Fetch CURRENT period orders
      Query currentOrdersQuery = _firestore.collectionGroup('order');
      if (filterType != DateFilterType.all) {
        currentOrdersQuery = currentOrdersQuery
            .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(currentStart))
            .where('orderDate', isLessThan: Timestamp.fromDate(currentEnd));
      }

      final currentOrdersSnapshot = await currentOrdersQuery.get();
      final List<OrdersModel> orders = currentOrdersSnapshot.docs.map((doc) {
        final userId = doc.reference.parent.parent?.id ?? '';
        return OrdersModel.fromJson(doc.data() as Map<String, dynamic>, doc.id).copyWith(customerId: userId);
      }).toList();

      // Fetch PREVIOUS period orders (for comparison)
      List<OrdersModel> previousOrders = [];
      if (filterType != DateFilterType.all) {
        final previousOrdersQuery = _firestore
            .collectionGroup('order')
            .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(previousStart))
            .where('orderDate', isLessThan: Timestamp.fromDate(previousEnd));

        final previousOrdersSnapshot = await previousOrdersQuery.get();
        previousOrders = previousOrdersSnapshot.docs.map((doc) {
          final userId = doc.reference.parent.parent?.id ?? '';
          return OrdersModel.fromJson(doc.data() as Map<String, dynamic>, doc.id).copyWith(customerId: userId);
        }).toList();
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

      // Fetch customers
      final customersSnapshot = await _firestore.collection('users').get();
      final totalCustomers = customersSnapshot.docs.length;

      // Calculate revenues for both periods
      double currentRevenue = orders
          .where((o) => o.orderStatus == 'completed')
          .fold(0.0, (sum, o) => sum + o.totalAmount);

      double previousRevenue = previousOrders
          .where((o) => o.orderStatus == 'completed')
          .fold(0.0, (sum, o) => sum + o.totalAmount);

      // Calculate period-specific status counts
      int periodCompleted = orders.where((o) => o.orderStatus == 'completed').length;
      int periodCancelled = orders.where((o) => o.orderStatus == 'cancelled').length;

      // Calculate changes using the same logic
      int orderChange = _calculatePercentageChange(orders.length, previousOrders.length);
      int revenueChange = _calculatePercentageChange(currentRevenue, previousRevenue);

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

      return DashboardStats(
        // Business metrics (filtered by date)
        totalRevenue: currentRevenue.toInt(),
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

        // Changes (now properly calculated)
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

  Future<Map<String, dynamic>> fetchCategorySales(DateTime selectedMonth) async {
    try {
      final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);

      Map<String, dynamic> categoryData = {};

      // Get all users
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();

      for (final userDoc in usersSnapshot.docs) {
        // Get orders for the selected month
        final ordersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('order')
            .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .where('orderDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
            .where('orderStatus', isEqualTo: 'completed') // Only completed orders
            .get();

        for (final orderDoc in ordersSnapshot.docs) {
          // Get order products for each order
          final orderProductsSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('order')
              .doc(orderDoc.id)
              .collection('orderProducts')
              .get();

          for (final orderProductDoc in orderProductsSnapshot.docs) {
            final orderProductData = orderProductDoc.data();
            final productRef = orderProductData['productID'] as DocumentReference;
            final quantity = orderProductData['productQuantity'] as int;
            final totalPrice = (orderProductData['totalPrice'] as num).toDouble();

            // Get product details
            final productDoc = await productRef.get();
            if (productDoc.exists) {
              final productData = productDoc.data() as Map<String, dynamic>;
              final categoryRef = productData['category'] as DocumentReference;

              // Get category details
              final categoryDoc = await categoryRef.get();
              if (categoryDoc.exists) {
                final categoryData_doc = categoryDoc.data() as Map<String, dynamic>;
                final categoryName = categoryData_doc['catName'] as String;

                // Accumulate data for this category
                if (categoryData.containsKey(categoryName)) {
                  categoryData[categoryName]['units'] += quantity;
                  categoryData[categoryName]['revenue'] += totalPrice;
                } else {
                  categoryData[categoryName] = {
                    'units': quantity,
                    'revenue': totalPrice,
                  };
                }
              }
            }
          }
        }
      }

      return categoryData.isNotEmpty ? categoryData : {
        'No Data': {'units': 0, 'revenue': 0.0},
      };

    } catch (e) {
      print('Error fetching category sales: $e');
      // Return empty data on error
      return {
        'Error': {'units': 0, 'revenue': 0.0},
      };
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

  Future<String> getCurrentAdminName() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          return userData?['name'] ?? userData?['fullName'] ?? 'Admin';
        }
      }
      return 'Admin';
    } catch (e) {
      print('Error fetching admin name: $e');
      return 'Admin';
    }
  }

  Future<Map<String, dynamic>> calculatePerformanceMetricsForPeriod({
    DateFilterType filterType = DateFilterType.month,
    DateTime? selectedDate,
  }) async {
    final metrics = <String, dynamic>{};

    try {
      selectedDate ??= DateTime.now();
      final dateRanges = _calculateDateRanges(filterType, selectedDate);
      final currentStart = dateRanges['currentStart']!;
      final currentEnd = dateRanges['currentEnd']!;

      // Fetch orders for the SPECIFIC period (not just 200 recent)
      Query ordersQuery = _firestore.collectionGroup('order');
      if (filterType != DateFilterType.all) {
        ordersQuery = ordersQuery
            .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(currentStart))
            .where('orderDate', isLessThan: Timestamp.fromDate(currentEnd));
      }

      final ordersSnapshot = await ordersQuery.get();
      final periodOrders = ordersSnapshot.docs
          .where((doc) => doc.data() != null)
          .map((doc) => OrdersModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (periodOrders.isEmpty) {
        return {
          'avgProcessingHours': 'No data',
          'avgShippingHours': 'No data',
          'fulfillmentRate': 'No data',
          'avgCompletionHours': 'No data',
          'processingEfficiency': 'No data',
          'cancellationRate': 'No data',
        };
      }

      // Calculate average processing time
      double totalProcessingHours = 0;
      int processedOrdersCount = 0;

      for (final order in periodOrders) {
        if (order.toShipDate != null) {
          final processingTime = order.toShipDate!.difference(order.orderDate).inHours;
          if (processingTime >= 0) {
            totalProcessingHours += processingTime;
            processedOrdersCount++;
          }
        }
      }

      metrics['avgProcessingHours'] = processedOrdersCount > 0
          ? (totalProcessingHours / processedOrdersCount).round()
          : 0;

      // Calculate average shipping time
      double totalShippingHours = 0;
      int shippedOrdersCount = 0;

      for (final order in periodOrders) {
        DateTime? shippingStartDate;
        DateTime? deliveryDate;

        if (order.toReceiveDate != null) {
          shippingStartDate = order.toReceiveDate;
        } else if (order.toShipDate != null) {
          shippingStartDate = order.toShipDate;
        }

        if (order.completedDate != null) {
          deliveryDate = order.completedDate;
        }

        if (shippingStartDate != null && deliveryDate != null) {
          final shippingTime = deliveryDate.difference(shippingStartDate).inHours;
          if (shippingTime >= 0) {
            totalShippingHours += shippingTime;
            shippedOrdersCount++;
          }
        }
      }

      metrics['avgShippingHours'] = shippedOrdersCount > 0
          ? (totalShippingHours / shippedOrdersCount).round()
          : 'No data';

      // Calculate average completion time
      double totalCompletionHours = 0;
      int completedOrdersForTime = 0;

      for (final order in periodOrders) {
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
          : 'No data';

      // Calculate fulfillment rate
      final completedOrdersCount = periodOrders
          .where((order) => order.orderStatus == 'completed')
          .length;

      final nonCancelledOrdersCount = periodOrders
          .where((order) => order.orderStatus != 'cancelled')
          .length;

      metrics['fulfillmentRate'] = nonCancelledOrdersCount > 0
          ? ((completedOrdersCount / nonCancelledOrdersCount) * 100).round()
          : 'No data';

      // Calculate processing efficiency
      final ordersProcessedWithin24h = periodOrders.where((order) {
        if (order.toShipDate == null) return false;
        final processingTime = order.toShipDate!.difference(order.orderDate).inHours;
        return processingTime <= 24 && processingTime >= 0;
      }).length;

      final totalProcessableOrders = periodOrders
          .where((order) => order.toShipDate != null || order.orderStatus == 'to_ship')
          .length;

      metrics['processingEfficiency'] = totalProcessableOrders > 0
          ? ((ordersProcessedWithin24h / totalProcessableOrders) * 100).round()
          : 'No data';  // Changed from 0 to 'No data'

      // Calculate cancellation rate
      final cancelledOrdersCount = periodOrders
          .where((order) => order.orderStatus == 'cancelled')
          .length;

      metrics['cancellationRate'] = periodOrders.isNotEmpty
          ? ((cancelledOrdersCount / periodOrders.length) * 100).round()
          : 'No data';

    } catch (e) {
      print('Error calculating performance metrics for period: $e');
      return {
        'avgProcessingHours': 'No data',
        'avgShippingHours': 'No data',
        'fulfillmentRate': 'No data',
        'avgCompletionHours': 'No data',
        'processingEfficiency': 'No data',
        'cancellationRate': 'No data',
      };
    }

    return metrics;
  }

  Future<Map<String, dynamic>> fetchPerformanceMetricsForPeriod({
    DateFilterType filterType = DateFilterType.month,
    DateTime? selectedDate,
  }) async {
    selectedDate ??= DateTime.now();

    // Calculate current period metrics
    final currentMetrics = await calculatePerformanceMetricsForPeriod(
      filterType: filterType,
      selectedDate: selectedDate,
    );

    // Calculate previous period metrics for comparison
    DateTime previousDate;
    switch (filterType) {
      case DateFilterType.day:
        previousDate = selectedDate.subtract(const Duration(days: 1));
        break;
      case DateFilterType.month:
        previousDate = DateTime(
          selectedDate.month == 1 ? selectedDate.year - 1 : selectedDate.year,
          selectedDate.month == 1 ? 12 : selectedDate.month - 1,
          selectedDate.day,
        );
        break;
      case DateFilterType.year:
        previousDate = DateTime(selectedDate.year - 1, selectedDate.month, selectedDate.day);
        break;
      case DateFilterType.all:
      // No comparison for 'all time'
        return currentMetrics;
    }

    final previousMetrics = await calculatePerformanceMetricsForPeriod(
      filterType: filterType,
      selectedDate: previousDate,
    );

    // Calculate changes for metrics that have numeric values
    final result = Map<String, dynamic>.from(currentMetrics);

    // Add change calculations
    result['avgProcessingHoursChange'] = _calculateMetricChange(
        currentMetrics['avgProcessingHours'],
        previousMetrics['avgProcessingHours']
    );

    result['avgShippingHoursChange'] = _calculateMetricChange(
        currentMetrics['avgShippingHours'],
        previousMetrics['avgShippingHours']
    );

    result['avgCompletionHoursChange'] = _calculateMetricChange(
        currentMetrics['avgCompletionHours'],
        previousMetrics['avgCompletionHours']
    );

    result['fulfillmentRateChange'] = _calculateMetricChange(
        currentMetrics['fulfillmentRate'],
        previousMetrics['fulfillmentRate']
    );

    result['processingEfficiencyChange'] = _calculateMetricChange(
        currentMetrics['processingEfficiency'],
        previousMetrics['processingEfficiency']
    );

    result['cancellationRateChange'] = _calculateMetricChange(
        currentMetrics['cancellationRate'],
        previousMetrics['cancellationRate']
    );

    return result;
  }

  int? _calculateMetricChange(dynamic currentValue, dynamic previousValue) {
    // Return null if either value is 'No data'
    if (currentValue is String || previousValue is String) return null;
    if (currentValue == 0 && previousValue == 0) return null;

    if (previousValue == 0) {
      return currentValue > 0 ? 100 : 0;
    }

    double change = ((currentValue - previousValue) / previousValue) * 100;
    return change.round();
  }
}
