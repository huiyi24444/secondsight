// cancel_order_dialog_controller.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secondsight/controller/order/notif_controller.dart';

class CancelOrderDialogController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // State variables
  String? _selectedReason;
  final TextEditingController customReasonController = TextEditingController();
  bool _isProcessing = false;

  // Cancellation reasons
  final List<String> cancellationReasons = [
    'Changed my mind',
    'Found a better price elsewhere',
    'Product no longer needed',
    'Other (please specify)',
  ];

  // Getters
  String? get selectedReason => _selectedReason;
  bool get isProcessing => _isProcessing;
  bool get showCustomReasonField => _selectedReason == 'Other (please specify)';

  // Check if can proceed
  bool get canProceed {
    return _selectedReason != null &&
        (_selectedReason != 'Other (please specify)' ||
            customReasonController.text.trim().isNotEmpty);
  }

  // Set selected reason
  void setSelectedReason(String reason) {
    _selectedReason = reason;
    notifyListeners();
  }

  // Set processing state
  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  // Get final cancellation data
  // Get enhanced cancellation data for the new cancellation model
  Map<String, String?> getCancellationData() {
    String cancellationReason = _selectedReason!;
    String? cancelNote;

    if (_selectedReason == 'Other (please specify)') {
      final customText = customReasonController.text.trim();
      if (customText.isNotEmpty) {
        cancellationReason = customText;
        cancelNote = 'Custom reason provided by customer';
      } else {
        cancellationReason = 'Other';
      }
    } else {
      if (customReasonController.text.trim().isNotEmpty) {
        cancelNote = customReasonController.text.trim();
      }
    }

    return {
      'cancellationReason': cancellationReason,
      'cancelNote': cancelNote,
    };
  }

  // Enhanced cancellation process with automatic refund creation
  Future<void> processOrderCancellationWithRefund({
    required String orderId,
    required String customerId,
    required VoidCallback onComplete,
    VoidCallback? onError,
  }) async {
    setProcessing(true);

    try {
      final cancellationData = getCancellationData();

      final orderDoc = await _firestore
          .collection('users')
          .doc(customerId)
          .collection('order')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      final currentStatus = orderData['orderStatus']?.toString().toLowerCase();

      if (!['pending', 'to_ship', 'confirmed'].contains(currentStatus)) {
        throw Exception('Order cannot be cancelled at this stage');
      }

      final orderTotal = (orderData['totalAmount'] ?? 0.0) as double;
      final paymentMethod = orderData['paymentMethod'] ?? 'Original Payment Method';
      final payment = orderData['payment'] ?? 'Unknown';

      final cancellationRef = _firestore.collection('cancellation').doc();
      final refundRef = _firestore.collection('refunds').doc();

      final cancellationDataForFirestore = {
        'referenceID': orderId,
        'cancellationType': 'order',
        'cancelReason': cancellationData['cancellationReason'],
        'cancelDate': FieldValue.serverTimestamp(),
        'cancelNote': cancellationData['cancelNote'],
        'cancelledBy': 'customer',
        'orderID': orderId,
      };

      final refundData = {
        'orderId': orderId,
        'returnRequestId': null,
        'cancelId': cancellationRef.id,
        'refundAmount': orderTotal,
        'refundMethod': paymentMethod,
        'refundDate': FieldValue.serverTimestamp(),
        'transactionId': payment,
        'customerId': customerId,
        'refundType': 'cancellation',
      };

      final batch = _firestore.batch();
      batch.set(cancellationRef, cancellationDataForFirestore);
      batch.set(refundRef, refundData);
      batch.update(
        _firestore.collection('users').doc(customerId).collection('order').doc(orderId),
        {
          'orderStatus': 'cancelled',
          'cancelDate': FieldValue.serverTimestamp(),
          'cancelID': cancellationRef.id,
          'refundID': refundRef.id,
        },
      );

      await batch.commit();

      // 🔹 Create cancellation notification after batch success
      await NotificationController.createOrderCancellationNotification(
        customerId: customerId,
        orderId: orderId,
        cancellationReason: cancellationData['cancellationReason'] ?? '',
        cancelNote: cancellationData['cancelNote'],
      );

      await Future.delayed(const Duration(milliseconds: 500));

      setProcessing(false);
      onComplete();

    } catch (e) {
      setProcessing(false);
      onError?.call();
      rethrow;
    }
  }

  @override
  void dispose() {
    customReasonController.dispose();
    super.dispose();
  }
}