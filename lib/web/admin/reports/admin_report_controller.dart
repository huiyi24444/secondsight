import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../model/order_model.dart';

class AdminReportController {
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
}
