import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../model/return_request_model.dart';

class ReturnManagementController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> returns = [];
  List<Map<String, dynamic>> filteredReturns = [];
  bool isLoading = true;
  String selectedTab = 'All';
  int currentPage = 1;
  int itemsPerPage = 10;

  Future<void> loadReturns() async {
    isLoading = true;
    notifyListeners();

    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final List<Map<String, dynamic>> loadedReturns = [];

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userEmail = userData['email'] ?? 'Unknown';

        final returnRequestsSnapshot =
        await userDoc.reference.collection('returnRequests').get();

        for (final returnDoc in returnRequestsSnapshot.docs) {
          final returnRequest = ReturnRequestModel.fromDocument(returnDoc);

          loadedReturns.add({
            'id': returnRequest.id,
            'userEmail': userEmail,
            'returnRequest': returnRequest,
          });
        }
      }


      final mappedReturns = await Future.wait(loadedReturns.map((entry) async {
        final returnRequest = entry['returnRequest'];
        final orderProductRef = returnRequest.orderProductID;
        final orderProductDoc = await orderProductRef.get();
        final orderProductData = orderProductDoc.data() as Map<String, dynamic>? ?? {};

        String orderId = 'N/A';
        String userEmail = 'Unknown';
        double returnPrice = (returnRequest.returnPrice ?? 0).toDouble(); // ✅ fixed

        final orderRef = orderProductRef.parent.parent;
        if (orderRef != null) {
          final orderDoc = await orderRef.get();
          final orderData = orderDoc.data() as Map<String, dynamic>? ?? {};

          orderId = orderRef.id;
          userEmail = orderData['userEmail'] ?? '';
        }

        return {
          'id': entry['id'],
          'userEmail': entry['userEmail'],
          'returnId': entry['id'].substring(0, 8).toUpperCase(),
          'shortOrderId': orderId.length >= 6 ? orderId.substring(0, 6).toUpperCase() : orderId.toUpperCase(),
          'orderProductId': orderProductRef.id,
          'date': returnRequest.returnDate.millisecondsSinceEpoch,
          'returnPrice': returnPrice,
          'status': returnRequest.returnStatus,
          'reason': returnRequest.returnReason,
          'items': orderProductData['items'] ?? [],
        };
      }));


      returns = mappedReturns;
      filterReturns();
    } catch (e) {
      print('Error loading returns: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  void filterReturns() {
    List<Map<String, dynamic>> filtered = returns;

    if (selectedTab != 'All') {
      filtered = filtered.where((returnItem) {
        switch (selectedTab) {
          case 'Pending':
            return returnItem['status'] == 'pending';
          case 'Approved':
            return returnItem['status'] == 'approved';
          case 'Refunded':
            return returnItem['status'] == 'refunded';
          case 'Cancelled':
            return returnItem['status'] == 'cancelled';
          default:
            return true;
        }
      }).toList();
    }

    if (searchController.text.isNotEmpty) {
      filtered = filtered.where((returnItem) {
        final search = searchController.text.toLowerCase();
        return returnItem['returnId'].toLowerCase().contains(search) ||
            returnItem['orderId'].toLowerCase().contains(search) ||
            returnItem['customer'].toLowerCase().contains(search);
      }).toList();
    }

    filteredReturns = filtered;
    currentPage = 1;
    notifyListeners();
  }

  Future<void> updateReturnStatus(BuildContext context, String userEmail, String returnId, String newStatus) async {
    try {
      final returnRef = _firestore.collection('users').doc(userEmail).collection('returnRequests').doc(returnId);
      await returnRef.update({'returnStatus': newStatus});

      if (newStatus == 'refunded') {
        final returnDoc = await returnRef.get();
        final returnData = ReturnRequestModel.fromDocument(returnDoc);
        final orderRef = returnData.orderProductID;
        await orderRef.update({'orderStatus': 'refunded'});
      }

      await loadReturns();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Return status updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating return: $e')),
      );
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'refunded':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1);
  }

  String formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day} ${_getMonth(date.month)} ${date.year}';
  }

  String _getMonth(int month) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
