import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../../model/user_model.dart';

class AdminDashboardController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<DashboardStats> fetchDashboardStats() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('order')
          .limit(10)
          .get();

      print("\u{1F525} Total recent orders fetched: \${snapshot.docs.length}");

      for (var doc in snapshot.docs) {
        print("\u{1F4DD} Raw order document: \${doc.data()}");
      }

      final ordersSnapshot = await _firestore.collectionGroup('order').get();
      final List<OrdersModel> orders = ordersSnapshot.docs
          .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
          .toList();

      final customersSnapshot = await _firestore.collection('users').get();
      final List<CustomerModel> customers = customersSnapshot.docs
          .map((doc) => CustomerModel.fromJson(doc.data(), doc.id))
          .toList();

      double revenue = orders
          .where((o) => o.orderStatus == 'completed')
          .fold(0.0, (sum, o) => sum + o.totalAmount);

      int completed = orders.where((o) => o.orderStatus == 'completed').length;
      int pending = orders.where((o) => o.orderStatus == 'pending_payment').length;
      int active = orders
          .where((o) => o.orderStatus == 'processing' || o.orderStatus == 'shipped')
          .length;
      int cancelled = orders.where((o) => o.orderStatus == 'cancelled').length;

      final recentOrdersSnapshot = await FirebaseFirestore.instance
          .collectionGroup('order')
          .orderBy('orderDate', descending: true)
          .orderBy('orderStatus')
          .limit(10)
          .get();

      print('Fetched recent orders: \${recentOrdersSnapshot.docs.length}');
      print('Recent orders raw data: \${recentOrdersSnapshot.docs.map((d) => d.data())}');

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
        cancelledOrders: cancelled,
        recentOrders: recentOrders,
        rawOrderDocs: recentOrdersSnapshot.docs,
      );
    } catch (e) {
      print('Error fetching dashboard stats: \$e');
      rethrow;
    }
  }

  Future<List<OrderProductModel>> fetchOrderProductsFromOrderDoc(DocumentSnapshot orderDoc) async {
    final userDocRef = orderDoc.reference.parent.parent;
    final orderId = orderDoc.id;

    if (userDocRef == null) {
      throw Exception("User document reference not found for order \$orderId");
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
  final int pendingOrders;
  final int activeOrders;
  final int cancelledOrders;
  final List<OrdersModel> recentOrders;
  final List<DocumentSnapshot> rawOrderDocs;

  DashboardStats({
    required this.totalRevenue,
    required this.totalCustomers,
    required this.allOrders,
    required this.completedOrders,
    required this.pendingOrders,
    required this.activeOrders,
    required this.cancelledOrders,
    required this.recentOrders,
    required this.rawOrderDocs,
  });
}