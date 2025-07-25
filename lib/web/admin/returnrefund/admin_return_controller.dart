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
      // Access the top-level returnRequests collection directly
      final returnRequestsSnapshot = await _firestore.collection('returnRequests').get();
      final List<Map<String, dynamic>> loadedReturns = [];

      for (final returnDoc in returnRequestsSnapshot.docs) {
        final returnRequest = ReturnRequestModel.fromDocument(returnDoc);

        // Get user email using the userID from the return request
        String userEmail = 'Unknown';
        try {
          final userDoc = await _firestore.collection('users').doc(returnRequest.userID).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>?;
            userEmail = userData?['email'] ?? 'Unknown';
          }
        } catch (e) {
          print('Error fetching user email for ${returnRequest.userID}: $e');
        }

        loadedReturns.add({
          'id': returnRequest.id,
          'userEmail': userEmail,
          'returnRequest': returnRequest,
        });
      }

      // Map the returns with additional data
      final mappedReturns = await Future.wait(loadedReturns.map((entry) async {
        final returnRequest = entry['returnRequest'] as ReturnRequestModel;

        // Get order product data using the stored IDs
        Map<String, dynamic> orderProductData = {};
        String orderId = returnRequest.orderID;

        try {
          final orderProductDoc = await _firestore
              .collection('users')
              .doc(returnRequest.userID)
              .collection('order')
              .doc(returnRequest.orderID)
              .collection('orderProducts')
              .doc(returnRequest.orderProductID)
              .get();

          if (orderProductDoc.exists) {
            orderProductData = orderProductDoc.data() as Map<String, dynamic>? ?? {};
          }
        } catch (e) {
          print('Error fetching order product data: $e');
        }

        return {
          'id': entry['id'],
          'userEmail': entry['userEmail'],
          'returnId': entry['id'].substring(0, 8).toUpperCase(),
          'shortOrderId': orderId.length >= 6 ? orderId.substring(0, 6).toUpperCase() : orderId.toUpperCase(),
          'orderProductId': returnRequest.orderProductID,
          'date': returnRequest.returnDate.millisecondsSinceEpoch,
          'returnPrice': returnRequest.returnPrice, // This is now directly available
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
    final returnRef = _firestore.collection('returnRequests').doc(returnId);
    await returnRef.update({'returnStatus': newStatus});

    if (newStatus == 'refunded') {
      final returnDoc = await returnRef.get();
      final returnData = ReturnRequestModel.fromDocument(returnDoc);

      // Extract necessary data
      final userId = returnData.userID;  // Make sure your model has this field
      final orderId = returnData.orderID; // Also ensure this exists
      final orderProductId = returnData.orderProductID;

      final orderProductRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('order')
          .doc(orderId)
          .collection('orderProducts')
          .doc(orderProductId);

      await orderProductRef.update({'orderStatus': 'refunded'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Return status updated successfully')),
      );
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
