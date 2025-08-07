// ===== ORDER MANAGEMENT CONTROLLER =====
// order_management_controller.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../model/cancel_model.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../../model/payment_cards_model.dart';
import '../../../model/shipment_model.dart';

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

      // Create cancellation document reference
      final cancellationRef = firestore
          .collection('cancellation')
          .doc();

      // Prepare cancellation data
      final cancellationData = {
        'orderID': orderId,
        'cancelReason': cancellationReason,
        'cancelDate': Timestamp.now(),
        'cancelNote': cancelNote,
        'cancelledBy': 'Admin', // Since this is from admin panel
      };

      // Use batch write for atomicity
      final batch = firestore.batch();

      // Create cancellation document
      batch.set(cancellationRef, cancellationData);

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
    String? paymentStatus,
  }) async {
    final results = await Future.wait([
      fetchShipmentData(customerId: customerId, orderId: orderId),
      fetchPaymentData(customerId: customerId, paymentStatus: paymentStatus),
    ]);

    return OrderData(
      shipment: results[0] as ShipmentModel?,
      paymentCard: results[1] as PaymentCard?,
    );
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
      debugPrint('Error fetching shipment: $e');
      return null;
    }
  }

  Future<PaymentCard?> fetchPaymentData({
    required String customerId,
    String? paymentStatus,
    String? paymentCardId, // NEW: Optional parameter for specific card ID
  }) async {
    try {
      if (paymentStatus == null || paymentStatus == 'Pending') {
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
      debugPrint('Error fetching payment card: $e');
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
      debugPrint('Error fetching payment card details: $e');
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
      debugPrint('Error checking return request: $e');
      return false;
    }
  }

  Future<CancellationModel?> getCancellationDetails(String cancelID) async {
    try {
      print('Fetching cancellation details for cancelID: $cancelID');

      final doc = await FirebaseFirestore.instance
          .collection('cancellation')
          .doc(cancelID)
          .get();

      if (!doc.exists) {
        debugPrint('Cancellation document not found for ID: $cancelID');
        return null;
      }

      debugPrint('Cancellation document fetched successfully for ID: $cancelID');
      return CancellationModel.fromDocument(doc);
    } catch (e, stackTrace) {
      debugPrint('Error fetching cancellation details for ID: $cancelID -> $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }


}
