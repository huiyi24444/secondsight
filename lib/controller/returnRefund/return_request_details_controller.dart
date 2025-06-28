import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../model/return_request_model.dart';
import '../../model/order_product_model.dart';

class ReturnRequestDetailsController {
  Stream<DocumentSnapshot> getReturnRequestStream(String userId, String returnRequestId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('returnRequests')
        .doc(returnRequestId)
        .snapshots();
  }

  Stream<QuerySnapshot> getRefundStream(String userId, String returnRequestId) {
    return FirebaseFirestore.instance
        .collection('refunds')
        .where('userId', isEqualTo: userId)
        .where('returnRequestId', isEqualTo: returnRequestId)
        .snapshots();
  }


  Future<DocumentSnapshot> getOrderProductDoc(DocumentReference orderProductRef) {
    return orderProductRef.get();
  }

  Future<DocumentSnapshot?> getProductDoc(DocumentReference? productRef) async {
    return productRef?.get();
  }

  String formatDate(DateTime dateTime) {
    return DateFormat('dd MMM yyyy').format(dateTime);
  }



  String getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return 'Submitted';
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      case 'processing':
        return 'Processing';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  //progress stepper
  Map<String, dynamic> getReturnStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
      case 'pending':
        return {
          'title': 'Return In Progress',
          'steps': ['Request Submitted', 'Under Review', 'Processing', 'Completed'],
          'currentStep': 0,
        };
      case 'approved':
        return {
          'title': 'Return Approved',
          'steps': ['Request Submitted', 'Approved', 'Processing', 'Completed'],
          'currentStep': 1,
        };
      case 'processing':
        return {
          'title': 'Processing Return',
          'steps': ['Request Submitted', 'Approved', 'Processing', 'Completed'],
          'currentStep': 2,
        };
      case 'completed':
        return {
          'title': 'Return Completed',
          'steps': ['Request Submitted', 'Approved', 'Processing', 'Completed'],
          'currentStep': 3,
        };
      case 'rejected':
        return {
          'title': 'Return Rejected',
          'steps': ['Request Submitted', 'Rejected'],
          'currentStep': 1,
        };
      default:
        return {
          'title': 'Return Status',
          'steps': ['Request Submitted', 'Under Review', 'Processing', 'Completed'],
          'currentStep': 0,
        };
    }
  }

  int _getReturnStep(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
      case 'request_submitted':
        return 0;
      case 'pending':
      case 'pending_approval':
        return 1;
      case 'approved':
      case 'request_approved':
        return 2;
      default:
        return 0;
    }
  }

} // End of controller