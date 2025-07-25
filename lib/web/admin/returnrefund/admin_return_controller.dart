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

  // Add this method to the controller
  Future<DocumentSnapshot> getOrderProductDoc(String userId, String orderID, String orderProductID) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('order')
        .doc(orderID)
        .collection('orderProducts')
        .doc(orderProductID)
        .get();
  }

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

        // Get order product data using the controller method
        Map<String, dynamic> orderProductData = {};
        String orderId = returnRequest.orderID;

        try {
          final orderProductDoc = await getOrderProductDoc(
              returnRequest.userID,
              returnRequest.orderID,
              returnRequest.orderProductID
          );

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
          case 'Submitted':  // Updated from 'Pending'
            return returnItem['status'] == 'submitted';
          case 'Approved':
            return returnItem['status'] == 'approved';
          case 'Completed':  // Updated from 'Refunded'
            return returnItem['status'] == 'completed';
          case 'Rejected':
            return returnItem['status'] == 'rejected';
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
            returnItem['shortOrderId'].toLowerCase().contains(search) ||  // Updated from 'orderId'
            returnItem['userEmail'].toLowerCase().contains(search);        // Updated from 'customer'
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
      final userId = returnData.userID;
      final orderId = returnData.orderID;
      final orderProductId = returnData.orderProductID;

      // Use the controller method here too for consistency
      try {
        final orderProductDoc = await getOrderProductDoc(userId, orderId, orderProductId);
        if (orderProductDoc.exists) {
          await orderProductDoc.reference.update({'orderStatus': 'refunded'});
        }
      } catch (e) {
        print('Error updating order product status: $e');
      }

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