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




} // End of controller