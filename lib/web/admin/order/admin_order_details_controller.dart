// ===== ORDER MANAGEMENT CONTROLLER =====
// order_management_controller.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../controller/order/notif_controller.dart';
import '../../../model/cancel_model.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../../model/payment_cards_model.dart';
import '../../../model/return_request_model.dart';
import '../../../model/shipment_model.dart';
import '../../../view/widgets/return_status_utils.dart';

class TimelineItem {
  final String title;
  final DateTime? date;
  final IconData icon;
  final Color color;
  final bool isCompleted;
  final bool isFirst;
  final bool isLast;

  TimelineItem({
    required this.title,
    this.date,
    required this.icon,
    required this.color,
    required this.isCompleted,
    this.isFirst = false,
    this.isLast = false,
  });
}

class OrderData {
  final ShipmentModel? shipment;
  final PaymentCard? paymentCard;

  OrderData({this.shipment, this.paymentCard});
}

class OrderDetailsManagementController {
  final FirebaseFirestore firestore;

  OrderDetailsManagementController({required this.firestore});

  // Status transition validation constants
  static const Map<String, List<String>> allowedTransitions = {
    'to_ship': ['to_receive', 'cancelled'],
    'to_receive': ['completed', 'cancelled'],
    'completed': [],
    'cancelled': [],
  };

  // Validation result constants
  static const int VALIDATION_OK = 0;
  static const int NO_PAYMENT = 1;
  static const int INCOMPLETE_ADDRESS = 2;
  static const int NO_TRACKING = 3;
  static const int INVALID_TRANSITION = 4;

  // Check if status transition is allowed
  bool isTransitionAllowed(String fromStatus, String toStatus) {
    return allowedTransitions[fromStatus]?.contains(toStatus) ?? false;
  }

  // Get available statuses for dropdown
  List<String> getAvailableStatuses(String currentStatus) {
    List<String> statuses = [currentStatus];
    statuses.addAll(allowedTransitions[currentStatus] ?? []);
    return statuses;
  }

  // Get transition error message
  String getTransitionErrorMessage(String fromStatus, String toStatus) {
    if (fromStatus == 'completed') {
      return 'Completed orders cannot be modified.';
    } else if (fromStatus == 'cancelled') {
      return 'Cancelled orders cannot be reactivated.';
    } else if (fromStatus == 'to_receive' && toStatus == 'to_ship') {
      return 'Cannot revert to "To Ship" once tracking number is provided.';
    } else {
      return 'This status transition is not allowed.';
    }
  }

  // Validate ship to receive transition
  int validateShipToReceive({
    required OrdersModel order,
    required ShipmentModel? shipment,
  }) {
    // Check payment
    if (order.payment == null) {
      return NO_PAYMENT;
    }

    // Check shipping address
    if (!isShippingAddressComplete(shipment)) {
      return INCOMPLETE_ADDRESS;
    }

    // Check tracking number
    if (!hasTrackingNumber(shipment)) {
      return NO_TRACKING;
    }

    return VALIDATION_OK;
  }

  // Helper methods
  bool isShippingAddressComplete(ShipmentModel? shipment) {
    return shipment != null &&
        (shipment.fullName?.isNotEmpty ?? false) &&
        (shipment.phoneNum != null && shipment.phoneNum! > 0) &&
        (shipment.streetone?.isNotEmpty ?? false) &&
        (shipment.city?.isNotEmpty ?? false) &&
        (shipment.state?.isNotEmpty ?? false) &&
        (shipment.zipCode?.isNotEmpty ?? false);
  }

  bool hasTrackingNumber(ShipmentModel? shipment) {
    return shipment?.trackingNumber != null &&
        shipment!.trackingNumber!.isNotEmpty;
  }

  // Update order status
  Future<void> updateOrderStatus({
    required String customerId,
    required String orderId,
    required String newStatus,
  }) async {
    await firestore
        .collection('users')
        .doc(customerId)
        .collection('order')
        .doc(orderId)
        .update({'orderStatus': newStatus});
  }

  // Update order completion
  Future<void> updateOrderCompletion({
    required String customerId,
    required String orderId,
  }) async {
    await firestore
        .collection('users')
        .doc(customerId)
        .collection('order')
        .doc(orderId)
        .update({'completedDate': Timestamp.now()});
  }

  // Modified order cancellation to follow order controller's updateOrderCancellation
  Future<void> updateOrderCancellation({
    required String customerId,
    required String orderId,
    required String cancellationReason,
    String? cancelNote,
  }) async {
    try {
      // First, verify the order can be cancelled
      final orderDoc = await firestore
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

      if (currentStatus != 'to_ship') {
        throw Exception('Only orders with "To Ship" status can be cancelled');
      }

      // Get order details for refund
      final orderTotal = (orderData['totalAmount'] ?? 0.0) as double;
      final paymentMethod = orderData['paymentMethod'] ?? 'Original Payment Method';
      final payment = orderData['payment'] ?? 'Unknown'; // This will be used as transactionId

      // Create document references
      final cancellationRef = firestore.collection('cancellation').doc();
      final refundRef = firestore.collection('refunds').doc();

      // Prepare cancellation data using the enhanced CancellationModel structure
      final cancellationData = {
        'referenceID': orderId,
        'cancellationType': 'order', // Specify this is an order cancellation
        'cancelReason': cancellationReason,
        'cancelDate': Timestamp.now(),
        'cancelNote': cancelNote,
        'cancelledBy': 'Admin', // Since this is from admin panel
        // Include legacy fields for backward compatibility
        'orderID': orderId,
      };

      // Prepare refund data using the RefundModel structure
      final refundData = {
        'orderId': orderId,
        'returnRequestId': null, // null for cancellation refunds
        'cancelId': cancellationRef.id,
        'refundAmount': orderTotal,
        'refundMethod': paymentMethod,
        'refundDate': Timestamp.now(),
        'transactionId': payment, // Use 'payment' attribute as transactionId
        'customerId': customerId,
        'refundType': 'cancellation',
      };

      // Use batch write for atomicity
      final batch = firestore.batch();

      // Create cancellation document
      batch.set(cancellationRef, cancellationData);

      // Create refund document in top-level 'refunds' collection
      batch.set(refundRef, refundData);

      // Update order document
      batch.update(
        firestore
            .collection('users')
            .doc(customerId)
            .collection('order')
            .doc(orderId),
        {
          'orderStatus': 'cancelled',
          'cancelDate': Timestamp.now(),
          'cancelID': cancellationRef.id,
          'refundID': refundRef.id, // Link to refund document
        },
      );

      // Commit batch
      await batch.commit();

    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }

  // Update tracking number
  Future<bool> updateTrackingNumber({
    required String customerId,
    required String orderId,
    required String trackingNumber,
  }) async {
    try {
      final shipmentRef = firestore
          .collection('users')
          .doc(customerId)
          .collection('order')
          .doc(orderId)
          .collection('shipment');

      final snapshot = await shipmentRef.get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'trackingNumber': trackingNumber,
          'shippedDate': Timestamp.now(),
        });
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Error updating tracking number: $e');
    }
  }

  Future<void> updateOrderStatusWithNotification({
    required String customerId,
    required String orderId,
    required String newStatus,
    String? trackingNumber,
  }) async {
    try {
      // Get the current order to check the old status
      final orderDoc = await firestore
          .collection('users')
          .doc(customerId)
          .collection('order')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final currentStatus = orderDoc.data()?['orderStatus'] ?? '';

      // Update the order status
      await updateOrderStatus(
        customerId: customerId,
        orderId: orderId,
        newStatus: newStatus,
      );

      // Create notification for status change
      await NotificationController.createOrderStatusNotification(
        userId: customerId,
        orderId: orderId,
        orderStatus: newStatus,
      );

      // If changing to "to_receive" (shipped), include tracking number in notification
      if (newStatus == 'to_receive' && trackingNumber != null) {
        await _createTrackingNotification(
          customerId: customerId,
          orderId: orderId,
          trackingNumber: trackingNumber,
        );
      }

      // If order is completed, create delivery notification
      if (newStatus == 'completed') {
        await updateOrderCompletion(
          customerId: customerId,
          orderId: orderId,
        );
        await _createDeliveryNotification(
          customerId: customerId,
          orderId: orderId,
        );
      }
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Create tracking number notification
  Future<void> _createTrackingNotification({
    required String customerId,
    required String orderId,
    required String trackingNumber,
  }) async {
    await firestore.collection('notifications').add({
      'userId': customerId,
      'title': 'Tracking Number Available',
      'message': 'Your order #${orderId.substring(0, 6).toUpperCase()} has been shipped. Tracking: $trackingNumber',
      'type': 'order_status',
      'orderId': orderId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': {
        'orderStatus': 'shipped',
        'trackingNumber': trackingNumber,
      },
    });
  }

  /// Create delivery notification
  Future<void> _createDeliveryNotification({
    required String customerId,
    required String orderId,
  }) async {
    await firestore.collection('notifications').add({
      'userId': customerId,
      'title': 'Order Delivered!',
      'message': 'Your order #${orderId.substring(0, 6).toUpperCase()} has been delivered. Thank you for shopping with us!',
      'type': 'order_status',
      'orderId': orderId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': {
        'orderStatus': 'delivered',
        'showReview': true, // Can be used to show review prompt
      },
    });
  }

  /// Update tracking number with notification
  Future<bool> updateTrackingNumberWithNotification({
    required String customerId,
    required String orderId,
    required String trackingNumber,
  }) async {
    try {
      // Update tracking number
      bool updated = await updateTrackingNumber(
        customerId: customerId,
        orderId: orderId,
        trackingNumber: trackingNumber,
      );

      if (updated) {
        // Update order status to "to_receive" and send notification
        await updateOrderStatusWithNotification(
          customerId: customerId,
          orderId: orderId,
          newStatus: 'to_receive',
          trackingNumber: trackingNumber,
        );
      }

      return updated;
    } catch (e) {
      throw Exception('Error updating tracking number: $e');
    }
  }

  /// Update order cancellation with notification
  Future<void> updateOrderCancellationWithNotification({
    required String customerId,
    required String orderId,
    required String cancellationReason,
    String? cancelNote,
  }) async {
    try {
      // Perform the cancellation
      await updateOrderCancellation(
        customerId: customerId,
        orderId: orderId,
        cancellationReason: cancellationReason,
        cancelNote: cancelNote,
      );

      // Create cancellation notification
      await firestore.collection('notifications').add({
        'userId': customerId,
        'title': 'Order Cancelled',
        'message': 'Your order #${orderId.substring(0, 6).toUpperCase()} has been cancelled. Refund will be processed within 3-5 business days.',
        'type': 'order_status',
        'orderId': orderId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'orderStatus': 'cancelled',
          'cancellationReason': cancellationReason,
          'refundExpected': true,
        },
      });
    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }

  /// Update return request status with notification
  Future<bool> updateReturnStatusWithNotification({
    required String returnId,
    required String newStatus,
    required String customerId,
    required String orderId,
  }) async {
    try {
      // Update return status
      bool updated = await updateReturnStatus(returnId, newStatus);

      if (updated) {
        // Create appropriate notification based on return status
        String title = '';
        String message = '';

        switch (newStatus.toLowerCase()) {
          case 'approved':
            title = 'Return Request Approved';
            message = 'Your return request for order #${orderId.substring(0, 6).toUpperCase()} has been approved. Please ship the items back.';
            break;
          case 'rejected':
            title = 'Return Request Rejected';
            message = 'Your return request for order #${orderId.substring(0, 6).toUpperCase()} has been rejected. Contact support for more information.';
            break;
          case 'completed':
            title = 'Return Completed';
            message = 'Your return for order #${orderId.substring(0, 6).toUpperCase()} has been completed. Refund has been processed.';
            break;
          case 'pending_inspection':
            title = 'Items Received';
            message = 'We have received your returned items from order #${orderId.substring(0, 6).toUpperCase()}. Inspection in progress.';
            break;
          case 'completed_inspection':
            title = 'Inspection Completed';
            message = 'Inspection completed for your return from order #${orderId.substring(0, 6).toUpperCase()}. Refund will be processed soon.';
            break;
          default:
            return updated; // Don't send notification for other statuses
        }

        await firestore.collection('notifications').add({
          'userId': customerId,
          'title': title,
          'message': message,
          'type': 'order_status',
          'orderId': orderId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'metadata': {
            'returnId': returnId,
            'returnStatus': newStatus,
          },
        });
      }

      return updated;
    } catch (e) {
      return false;
    }
  }

  /// Batch update multiple orders with notifications
  Future<void> batchUpdateOrderStatuses({
    required List<Map<String, String>> orderUpdates, // List of {customerId, orderId, newStatus}
  }) async {
    final batch = firestore.batch();

    for (var update in orderUpdates) {
      final customerId = update['customerId']!;
      final orderId = update['orderId']!;
      final newStatus = update['newStatus']!;

      // Update order
      batch.update(
        firestore
            .collection('users')
            .doc(customerId)
            .collection('order')
            .doc(orderId),
        {'orderStatus': newStatus},
      );

      // Create notification
      final notificationRef = firestore.collection('notifications').doc();
      batch.set(notificationRef, {
        'userId': customerId,
        'title': 'Order Update',
        'message': 'Your order #${orderId.substring(0, 6).toUpperCase()} status has been updated to ${formatStatus(newStatus)}',
        'type': 'order_status',
        'orderId': orderId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'orderStatus': newStatus,
        },
      });
    }

    await batch.commit();
  }


  // Delete order
  Future<void> deleteOrder({
    required String customerId,
    required String orderId,
  }) async {
    await firestore
        .collection('users')
        .doc(customerId)
        .collection('order')
        .doc(orderId)
        .delete();
  }

  static const double SHIPPING_FEE = 8.00;

  double getShippingFee() => SHIPPING_FEE;

  double calculateSubtotal(List<OrderProductModel> products) {
    return products.fold(0, (sum, product) => sum + product.totalPrice);
  }

  double calculateGrandTotal(List<OrderProductModel> products) {
    return calculateSubtotal(products) + getShippingFee();
  }

  List<TimelineItem> getTimelineItems(OrdersModel order) {
    List<TimelineItem> items = [];

    // Order Created (always present)
    items.add(TimelineItem(
      title: 'Order Created',
      date: order.orderDate,
      icon: Icons.shopping_cart,
      color: Colors.grey[700]!,
      isCompleted: true,
      isFirst: true,
    ));

    // Order Confirmed
    if (order.confirmedDate != null) {
      items.add(TimelineItem(
        title: 'Order Confirmed',
        date: order.confirmedDate,
        icon: Icons.check_circle,
        color: Colors.grey[700]!,
        isCompleted: true,
      ));
    } else if (order.orderStatus != 'cancelled') {
      items.add(TimelineItem(
        title: 'Order Confirmed',
        date: null,
        icon: Icons.check_circle_outline,
        color: Colors.grey[400]!,
        isCompleted: false,
      ));
    }

    // To Ship
    if (order.toShipDate != null) {
      items.add(TimelineItem(
        title: 'Ready to Ship',
        date: order.toShipDate,
        icon: Icons.inventory,
        color: Colors.grey[700]!,
        isCompleted: true,
      ));
    } else if (['to_ship', 'to_receive', 'completed'].contains(order.orderStatus)) {
      items.add(TimelineItem(
        title: 'Ready to Ship',
        date: null,
        icon: Icons.inventory_outlined,
        color: Colors.grey[400]!,
        isCompleted: false,
      ));
    }

    // To Receive (Shipped)
    if (order.toReceiveDate != null) {
      items.add(TimelineItem(
        title: 'Shipped',
        date: order.toReceiveDate,
        icon: Icons.local_shipping,
        color: Colors.grey[700]!,
        isCompleted: true,
      ));
    } else if (['to_receive', 'completed'].contains(order.orderStatus)) {
      items.add(TimelineItem(
        title: 'Shipped',
        date: null,
        icon: Icons.local_shipping_outlined,
        color: Colors.grey[400]!,
        isCompleted: false,
      ));
    }

    // Completed or Cancelled
    if (order.completedDate != null) {
      items.add(TimelineItem(
        title: 'Delivered',
        date: order.completedDate,
        icon: Icons.done_all,
        color: Colors.green[700]!,
        isCompleted: true,
        isLast: true,
      ));
    } else if (order.cancelDate != null) {
      items.add(TimelineItem(
        title: 'Cancelled',
        date: order.cancelDate,
        icon: Icons.cancel,
        color: Colors.red[700]!,
        isCompleted: true,
        isLast: true,
      ));
    } else if (order.orderStatus != 'cancelled') {
      items.add(TimelineItem(
        title: 'Delivered',
        date: null,
        icon: Icons.done_all_outlined,
        color: Colors.grey[400]!,
        isCompleted: false,
        isLast: true,
      ));
    }

    return items;
  }


  Future<OrderData> loadOrderData({
    required String customerId,
    required String orderId,
    String? payment,
  }) async {
    final results = await Future.wait([
      fetchShipmentData(customerId: customerId, orderId: orderId),
      fetchPaymentData(customerId: customerId, payment: payment),
    ]);

    return OrderData(
      shipment: results[0] as ShipmentModel?,
      paymentCard: results[1] as PaymentCard?,
    );
  }

  Future<Map<String, dynamic>?> fetchCustomerDetails(String customerId) async {
    try {
      final doc = await firestore
          .collection('users')
          .doc(customerId)
          .get();

      if (doc.exists) {
        final userData = doc.data() as Map<String, dynamic>;
        return {
          'fullName': userData['fullName'] ?? 'Unknown',
          'phoneNum': userData['phoneNum']?.toString() ?? 'No phone number',
          'email': userData['email'] ?? 'No email',
          'profilePic': userData['profilePic'] ?? '',
          'isVerified': userData['isVerified'] ?? false,
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ShipmentModel?> fetchShipmentData({
    required String customerId,
    required String orderId,
  }) async {
    try {
      final shipmentSnapshot = await firestore
          .collection('users')
          .doc(customerId)
          .collection('order')
          .doc(orderId)
          .collection('shipment')
          .get();

      if (shipmentSnapshot.docs.isNotEmpty) {
        return ShipmentModel.fromMap(
          shipmentSnapshot.docs.first.data(),
          shipmentSnapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<PaymentCard?> fetchPaymentData({
    required String customerId,
    String? payment,
    String? paymentCardId, // NEW: Optional parameter for specific card ID
  }) async {
    try {
      if (payment == null || payment == 'Unknown') {
        return null;
      }

      // NEW: If paymentCardId is provided, fetch that specific card
      if (paymentCardId != null) {
        final cardDoc = await firestore
            .collection('users')
            .doc(customerId)
            .collection('paymentCards') // Changed from 'paymentMethods' to 'paymentCards'
            .doc(paymentCardId)
            .get();

        if (cardDoc.exists) {
          return PaymentCard.fromDocument(cardDoc);
        }
      }

      // Fallback: Find default payment method from paymentCards collection
      final paymentCardsSnapshot = await firestore
          .collection('users')
          .doc(customerId)
          .collection('paymentCards') // Changed from 'paymentMethods'
          .get();

      if (paymentCardsSnapshot.docs.isEmpty) {
        return null;
      }

      // Find default payment card
      QueryDocumentSnapshot<Map<String, dynamic>>? defaultPaymentDoc;
      for (var doc in paymentCardsSnapshot.docs) {
        if (doc.data()['isDefault'] == true) {
          defaultPaymentDoc = doc;
          break;
        }
      }

      defaultPaymentDoc ??= paymentCardsSnapshot.docs.first;
      return PaymentCard.fromDocument(defaultPaymentDoc);
    } catch (e) {
      return null;
    }
  }

  /// Fetch payment card details from paymentCards subcollection
  Future<Map<String, dynamic>?> fetchPaymentCardDetails({
    required String customerId,
    required String paymentCardId,
  }) async {
    try {
      final cardDoc = await firestore
          .collection('users')
          .doc(customerId)
          .collection('paymentCards')
          .doc(paymentCardId)
          .get();

      if (cardDoc.exists) {
        final data = cardDoc.data()!;
        return {
          'lastFour': data['lastFour'],
          'brand': data['brand'],
          // Add any other fields you need from the PaymentCard model
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }



  Future<bool> hasReturnRequest(String orderId) async {
    try {
      final query = await firestore
          .collection('returnRequests')
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<CancellationModel?> getCancellationDetails(String cancelID) async {
    try {

      final doc = await FirebaseFirestore.instance
          .collection('cancellation')
          .doc(cancelID)
          .get();

      if (!doc.exists) {
        return null;
      }
      return CancellationModel.fromDocument(doc);
    } catch (e, stackTrace) {
      return null;
    }
  }

  Future<bool> updateReturnStatus(String returnId, String newStatus) async {
    try {
      Map<String, dynamic> updateData = {'returnStatus': newStatus};

      // Add timestamp fields based on the new status
      switch (newStatus.toLowerCase()) {
        case 'pending':
          updateData['pendingDate'] = FieldValue.serverTimestamp();
          break;
        case 'approved':
          updateData['approvedDate'] = FieldValue.serverTimestamp();
          break;
        case 'rejected':
          updateData['rejectedDate'] = FieldValue.serverTimestamp();
          break;
        case 'completed':
          updateData['completedDate'] = FieldValue.serverTimestamp();
          break;
        case 'pending_inspection':
          updateData['pendinginspectionDate'] = FieldValue.serverTimestamp();
          break;
        case 'completed_inspection':
          updateData['completedinsepectionDate'] = FieldValue.serverTimestamp();
          break;
        case 'cancelled':
          updateData['cancelledDate'] = FieldValue.serverTimestamp();
          break;
      }

      await firestore
          .collection('returnRequests')
          .doc(returnId)
          .update(updateData);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Format return date for display
  String formatReturnDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('dd MMM, yyyy').format(date);
    }
  }

  String formatReturnStatus(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return 'Submitted';
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'refunded':
        return 'Refunded';
      case 'not_refunded':
        return 'Not Refunded';
      case 'cancelled':
        return 'Cancelled';
      case 'pending_inspection':
        return 'Pending Inspection';
      case 'completed_inspection':
        return 'Completed Inspection';
      case 'completed':
        return 'Completed';
      default:
        return status.substring(0, 1).toUpperCase() + status.substring(1);
    }
  }


  /// Get order product document
  Future<DocumentSnapshot?> getOrderProductDoc(String userId, String orderId, String orderProductId) async {
    try {
      final doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('order')
          .doc(orderId)
          .collection('orderProducts')
          .doc(orderProductId)
          .get();
      return doc.exists ? doc : null;
    } catch (e) {
      return null;
    }
  }

  /// Get return request model by ID
  Future<ReturnRequestModel?> getReturnRequestModel(String returnId) async {
    try {
      final returnDoc = await firestore
          .collection('returnRequests')
          .doc(returnId)
          .get();

      if (!returnDoc.exists) {
        throw Exception('Return request not found');
      }

      return ReturnRequestModel.fromDocument(returnDoc);
    } catch (e) {
      rethrow;
    }
  }

  /// Get stream of return requests for an order
  Stream<QuerySnapshot> getOrderReturnRequestsStream(String customerId, String orderId) {
    return firestore
        .collection('returnRequests')
        .where('userID', isEqualTo: customerId)
        .where('orderID', isEqualTo: orderId)
        .snapshots();
  }

  /// Format return request display data
  Map<String, dynamic> formatReturnRequestDisplayData(Map<String, dynamic> returnData) {
    final status = returnData['status'] ?? 'Pending';
    final createdAt = (returnData['createdTime'] as Timestamp?)?.toDate();
    final reason = returnData['reason'] ?? 'Not specified';

    return {
      'status': status,
      'createdAt': createdAt,
      'reason': reason,
      'formattedDate': createdAt != null
          ? DateFormat('MMM d, y').format(createdAt)
          : 'Unknown date',
      'statusColor': ReturnStatusUtils.getReturnStatusColor(status),
    };
  }

  /// Get return eligibility info
  Map<String, dynamic> getReturnEligibilityInfo(OrdersModel order) {
    if (!order.eligibilityForReturn) {
      return {
        'text': 'Not Eligible',
        'color': Colors.grey,
        'isEligible': false,
      };
    }

    if (order.orderStatus.toLowerCase() != 'completed' &&
        order.orderStatus.toLowerCase() != 'delivered') {
      return {
        'text': 'Not Eligible',
        'color': Colors.grey,
        'isEligible': false,
      };
    }

    if (order.completedDate != null) {
      final daysSinceCompleted = DateTime.now().difference(order.completedDate!).inDays;
      final daysRemaining = 5 - daysSinceCompleted;

      if (daysRemaining <= 0) {
        return {
          'text': 'Expired',
          'color': Colors.red,
          'isEligible': false,
        };
      } else if (daysRemaining == 1) {
        return {
          'text': 'Expires Today',
          'color': Colors.orange,
          'isEligible': true,
        };
      } else {
        return {
          'text': '$daysRemaining days remaining',
          'color': daysRemaining <= 2 ? Colors.amber : Colors.green,
          'isEligible': true,
        };
      }
    }

    return {
      'text': 'Yes',
      'color': Colors.green,
      'isEligible': true,
    };
  }


}
String formatStatus(String status) {
  switch (status.toLowerCase()) {
    case 'to_ship':
      return 'Ready to Ship';
    case 'to_receive':
      return 'Shipped';
    case 'completed':
      return 'Delivered';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}