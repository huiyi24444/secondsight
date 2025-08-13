import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/controller/order/notif_controller.dart';
import '../../model/return_request_model.dart';

void showCancelDialog(BuildContext context, String userId, ReturnRequestModel returnRequest) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Return Request',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Are you sure you want to cancel this return request? This action cannot be undone.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Keep Request',
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _cancelReturnRequest(context, userId, returnRequest);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Cancel Request',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _cancelReturnRequest(
    BuildContext context, String userId, ReturnRequestModel returnRequest) async {
  try {

    const String newStatus = 'cancelled';
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('returnRequests')
        .doc(returnRequest.id)
        .update({'returnStatus': 'cancelled'});

    await NotificationController.createReturnStatusNotification(
      returnId: returnRequest.id,
      newStatus: newStatus,
      customerId: userId,
      orderId: returnRequest.orderID,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Return request cancelled successfully'),
          backgroundColor: Color(0xFF8E6CEF),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
