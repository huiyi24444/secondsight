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
          'returnRequest': returnRequest, // ← KEEP THE ORIGINAL MODEL!
          'returnId': (entry['id'] as String? ?? '').length >= 8
              ? (entry['id'] as String).substring(0, 8).toUpperCase()
              : (entry['id'] as String? ?? '').toUpperCase(),
          'shortOrderId': orderId.length >= 6 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase(),
          'orderProductId': returnRequest.orderProductID ?? '',
          'date': returnRequest.returnDate?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
          'returnPrice': returnRequest.returnPrice ?? 0.0,
          'status': returnRequest.returnStatus ?? 'unknown',
          'reason': returnRequest.returnReason ?? 'No reason provided',
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
    try {
      // Special handling for cancelled status transition
      if (newStatus == 'cancelled') {
        // Get the return request details first
        final returnDoc = await _firestore
            .collection('returnRequests')
            .doc(returnId)
            .get();

        if (!returnDoc.exists) {
          throw Exception('Return request not found');
        }

        final returnData = ReturnRequestModel.fromDocument(returnDoc);

        // Create cancellation document reference
        final cancellationRef = _firestore.collection('cancellation').doc();

        // Prepare cancellation data using the enhanced CancellationModel structure
        final cancellationData = {
          'referenceID': returnId,
          'cancellationType': 'return_request', // Specify this is a return request cancellation
          'cancelReason': 'Return request cancelled by admin',
          'cancelDate': FieldValue.serverTimestamp(),
          'cancelNote': null,
          'cancelledBy': 'admin', // Since this is from admin panel
          // Include legacy field for backward compatibility
          'returnRequestID': returnId,
        };

        // Use batch write for atomicity
        final batch = _firestore.batch();

        // Create cancellation document
        batch.set(cancellationRef, cancellationData);

        // Update return request status
        batch.update(
          _firestore.collection('returnRequests').doc(returnId),
          {
            'returnStatus': newStatus,
            '${newStatus}Date': FieldValue.serverTimestamp(),
            'cancelID': cancellationRef.id, // Link to cancellation document
          },
        );

        // Commit batch
        await batch.commit();
      }
      // Special handling for refunded status transition
      else if (newStatus == 'refunded') {
        final returnRef = _firestore.collection('returnRequests').doc(returnId);
        final returnDoc = await returnRef.get();
        final returnData = ReturnRequestModel.fromDocument(returnDoc);

        // Extract necessary data
        final userId = returnData.userID;
        final orderId = returnData.orderID;
        final orderProductId = returnData.orderProductID;
        final refundAmount = (returnData.returnPrice ?? 0.0) as double;
        final returnQuantity = returnData.returnQuantity ?? 1;
        final totalRefundAmount = refundAmount * returnQuantity;

        // Get payment method from original order
        final orderDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('order')
            .doc(orderId)
            .get();

        final paymentMethod = orderDoc.exists
            ? (orderDoc.data() as Map<String, dynamic>)['paymentMethod'] ?? 'Original Payment Method'
            : 'Original Payment Method';

        final payment = orderDoc.exists
            ? (orderDoc.data() as Map<String, dynamic>)['payment'] ?? 'Unknown'
            : 'Unknown';

        // Create refund document reference
        final refundRef = _firestore.collection('refunds').doc();

        // Prepare refund data using the RefundModel structure
        final refundData = {
          'orderId': orderId,
          'returnRequestId': returnId,
          'cancelId': null, // null for return refunds
          'refundAmount': totalRefundAmount,
          'refundMethod': paymentMethod,
          'refundDate': FieldValue.serverTimestamp(),
          'transactionId': payment, // Use 'payment' attribute as transactionId
          'customerId': userId,
          'refundType': 'return',
        };

        // Use batch write for atomicity
        final batch = _firestore.batch();

        // Update return request status
        batch.update(
          _firestore.collection('returnRequests').doc(returnId),
          {
            'returnStatus': newStatus,
            '${newStatus}Date': FieldValue.serverTimestamp(),
            'refundID': refundRef.id, // Link to refund document
          },
        );

        // Create refund document in top-level 'refunds' collection
        batch.set(refundRef, refundData);

        // Update order product status
        try {
          final orderProductDoc = await getOrderProductDoc(userId, orderId, orderProductId);
          if (orderProductDoc.exists) {
            batch.update(orderProductDoc.reference, {'orderStatus': 'refunded'});
          }
        } catch (e) {
          print('Error preparing order product status update: $e');
        }

        // Commit batch
        await batch.commit();
      }
      else {
        // Standard status update for other statuses
        final returnRef = _firestore.collection('returnRequests').doc(returnId);
        await returnRef.update({
          'returnStatus': newStatus,
          '${newStatus}Date': FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Return status updated successfully')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update return status: $e'),
          backgroundColor: Colors.red,
        ),
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

  Future<List<ReturnRequestModel>> loadReturnsAsModels() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('returnRequests')
          .orderBy('returnDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ReturnRequestModel(
          id: doc.id,
          orderProductID: data['orderProductID'] ?? '',
          orderID: data['orderID'] ?? '',
          userID: data['userID'] ?? '',
          returnDate: data['returnDate'] ?? Timestamp.now(),
          returnImages: List<String>.from(data['returnImages'] ?? []),
          returnReason: data['returnReason'] ?? '',
          returnStatus: data['returnStatus'] ?? 'pending',
          returnComment: data['returnComment'] ?? '',
          rejectReason: data['rejectReason'],
          returnPrice: (data['returnPrice'] ?? 0.0).toDouble(),
          returnQuantity: data['returnQuantity'] ?? 1,
          productName: data['productName'] ?? 'Unknown Product',
          productImageUrl: data['productImageUrl'] ?? '',
          pendingDate: data['pendingDate'] as Timestamp?,
          approvedDate: data['approvedDate'] as Timestamp?,
          rejectedDate: data['rejectedDate'] as Timestamp?,
          completedDate: data['completedDate'] as Timestamp?,
          pendinginspectionDate: data['pendinginspectionDate'] as Timestamp?,
          completedinsepectionDate: data['completedinsepectionDate'] as Timestamp?,
          cancelledDate: data['cancelledDate'] as Timestamp?,
        );
      }).toList();
    } catch (e) {
      print('Error loading returns: $e');
      return [];
    }
  }
}