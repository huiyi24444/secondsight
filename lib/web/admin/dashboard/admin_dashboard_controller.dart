import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../model/order_model.dart';
import '../../../model/user_model.dart';

class AdminDashboardController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<DashboardStats> fetchDashboardStats() async {
    try {


      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('order')
          .orderBy('orderDate', descending: true)
          .limit(10)
          .get();

      print("🔥 Total recent orders fetched: ${snapshot.docs.length}");

      for (var doc in snapshot.docs) {
        print("📝 Raw order document: ${doc.data()}");
      }

      // Fetch orders
      final ordersSnapshot = await _firestore.collectionGroup('order').get();
      final List<OrdersModel> orders = ordersSnapshot.docs
          .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
          .toList();

      // Fetch customers
      final customersSnapshot = await _firestore.collection('users').get();
      final List<CustomerModel> customers = customersSnapshot.docs
          .map((doc) => CustomerModel.fromJson(doc.data(), doc.id))
          .toList();

      // Calculate order statistics
      double revenue = orders
          .where((o) => o.orderStatus == 'completed')
          .fold(0.0, (sum, o) => sum + o.totalAmount);

      int completed = orders.where((o) => o.orderStatus == 'completed').length;
      int pending = orders.where((o) => o.orderStatus == 'pending').length;
      int active = orders
          .where((o) => o.orderStatus == 'processing' || o.orderStatus == 'shipped')
          .length;

      // Get recent 10 orders
      final recentOrdersSnapshot = await FirebaseFirestore.instance
          .collectionGroup('order')
          .orderBy('orderDate', descending: true)
          .limit(10)
          .get();

      print('Fetched recent orders: ${recentOrdersSnapshot.docs.length}');
      print('Recent orders raw data: ${recentOrdersSnapshot.docs.map((d) => d.data())}');


      List<OrdersModel> recentOrders = recentOrdersSnapshot.docs
          .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
          .toList();

      return DashboardStats(
        totalRevenue: revenue.toInt(),
        totalCustomers: customers.length,
        allOrders: orders.length,
        completedOrders: completed,
        pendingOrders: pending,
        activeOrders: active,
        recentOrders: recentOrders,
      );
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      rethrow;
    }
  }
}

class DashboardStats {
  final int totalRevenue;
  final int totalCustomers;
  final int allOrders;
  final int completedOrders;
  final int pendingOrders;
  final int activeOrders;
  final List<OrdersModel> recentOrders;

  DashboardStats({
    required this.totalRevenue,
    required this.totalCustomers,
    required this.allOrders,
    required this.completedOrders,
    required this.pendingOrders,
    required this.activeOrders,
    required this.recentOrders,
  });
}
