import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../../model/shipment_model.dart';
import '../../../model/payment_cards_model.dart';

class OrderDetailsDialogController extends ChangeNotifier {
  final FirebaseFirestore firestore;

  // Define allowed status transitions
  static const Map<String, List<String>> allowedTransitions = {
    'to_ship': ['to_receive', 'canceled'],
    'to_receive': ['completed', 'canceled'],
    'completed': [], // No transitions allowed
    'canceled': [], // No transitions allowed
  };

  OrderDetailsDialogController({required this.firestore});

  // Fetch shipment information
  Future<ShipmentModel?> fetchShipment(String customerId, String orderId) async {
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
    } catch (e) {
      debugPrint('Error fetching shipment: $e');
    }
    return null;
  }

  // Fetch payment card information
  Future<PaymentCard?> fetchPaymentCard(OrdersModel order) async {
    try {
      if (order.payment != null && order.payment != 'Pending') {
        final paymentMethodsSnapshot = await firestore
            .collection('users')
            .doc(order.customerId)
            .collection('paymentMethods')
            .get();

        if (paymentMethodsSnapshot.docs.isNotEmpty) {
          QueryDocumentSnapshot<Map<String, dynamic>>? defaultPaymentDoc;

          // Try to find default payment method
          for (var doc in paymentMethodsSnapshot.docs) {
            if (doc.data()['isDefault'] == true) {
              defaultPaymentDoc = doc;
              break;
            }
          }

          // If no default found, use the first one
          defaultPaymentDoc ??= paymentMethodsSnapshot.docs.first;

          return PaymentCard.fromDocument(defaultPaymentDoc);
        }
      }
    } catch (e) {
      debugPrint('Error fetching payment card: $e');
    }
    return null;
  }

  // Get available statuses for dropdown
  List<String> getAvailableStatuses(String currentStatus) {
    List<String> statuses = [currentStatus];
    statuses.addAll(allowedTransitions[currentStatus] ?? []);
    return statuses;
  }

  // Check if transition is allowed
  bool isTransitionAllowed(String fromStatus, String toStatus) {
    return allowedTransitions[fromStatus]?.contains(toStatus) ?? false;
  }

  // Get transition error message
  String getTransitionErrorMessage(String fromStatus, String toStatus) {
    if (fromStatus == 'completed') {
      return 'Completed orders cannot be modified.';
    } else if (fromStatus == 'canceled') {
      return 'Canceled orders cannot be reactivated.';
    } else if (fromStatus == 'to_receive' && toStatus == 'to_ship') {
      return 'Cannot revert to "To Ship" once tracking number is provided.';
    } else {
      return 'This status transition is not allowed.';
    }
  }

  // Check if address is complete
  bool isAddressComplete(ShipmentModel? shipment) {
    return shipment != null &&
        (shipment.fullName?.isNotEmpty ?? false) &&
        (shipment.phoneNum != null && shipment.phoneNum! > 0) &&
        (shipment.streetone?.isNotEmpty ?? false) &&
        (shipment.city?.isNotEmpty ?? false) &&
        (shipment.state?.isNotEmpty ?? false) &&
        (shipment.zipCode?.isNotEmpty ?? false);
  }

  // Update order status
  Future<void> updateOrderStatus(
      OrdersModel order,
      String newStatus,
      Future<void> Function() reloadCallback,
      ) async {
    try {
      final updateData = <String, dynamic>{'orderStatus': newStatus};

      // Add timestamp based on status
      switch (newStatus) {
        case 'to_receive':
          updateData['toReceiveDate'] = Timestamp.now();
          break;
        case 'completed':
          updateData['completedDate'] = Timestamp.now();
          break;
        case 'canceled':
          updateData['canceledDate'] = Timestamp.now();
          break;
      }

      await firestore
          .collection('users')
          .doc(order.customerId)
          .collection('order')
          .doc(order.id)
          .update(updateData);

      await reloadCallback();
    } catch (e) {
      throw Exception('Error updating order: $e');
    }
  }

  // Update tracking number
  Future<void> updateTrackingNumber(
      OrdersModel order,
      String trackingNumber,
      ) async {
    try {
      final shipmentRef = firestore
          .collection('users')
          .doc(order.customerId)
          .collection('order')
          .doc(order.id)
          .collection('shipment');

      final snapshot = await shipmentRef.get();

      final updateData = {
        'trackingNumber': trackingNumber.trim(),
        'shippedDate': Timestamp.now(),
      };

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update(updateData);
      } else {
        throw Exception('Shipment document not found');
      }
    } catch (e) {
      throw Exception('Error updating tracking number: $e');
    }
  }

  // Update cancellation reason
  Future<void> updateCancellationReason(
      OrdersModel order,
      String reason,
      ) async {
    await firestore
        .collection('users')
        .doc(order.customerId)
        .collection('order')
        .doc(order.id)
        .update({
      'cancellationReason': reason.trim(),
      'canceledDate': Timestamp.now(),
    });
  }

  // Delete order
  Future<void> deleteOrder(OrdersModel order) async {
    await firestore
        .collection('users')
        .doc(order.customerId)
        .collection('order')
        .doc(order.id)
        .delete();
  }

  // Check if order can be deleted
  bool canDeleteOrder(String orderStatus) {
    return orderStatus != 'completed' && orderStatus != 'to_receive';
  }

  // Format date
  String formatDate(DateTime dateTime) {
    final formatter = DateFormat('dd MMM yyyy');
    return formatter.format(dateTime);
  }

  // Format date time
  String formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('dd MMM yyyy, HH:mm');
    return formatter.format(dateTime);
  }

  // Get payment status color
  Color getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Get card brand icon data
  Map<String, dynamic> getCardBrandIconData(String brand) {
    IconData iconData;
    Color iconColor;

    switch (brand.toLowerCase()) {
      case 'visa':
        iconData = Icons.credit_card;
        iconColor = const Color(0xFF1A1F71);
        break;
      case 'mastercard':
        iconData = Icons.credit_card;
        iconColor = const Color(0xFFEB001B);
        break;
      case 'amex':
      case 'american express':
        iconData = Icons.credit_card;
        iconColor = const Color(0xFF006FCF);
        break;
      case 'discover':
        iconData = Icons.credit_card;
        iconColor = const Color(0xFFFF6000);
        break;
      default:
        iconData = Icons.credit_card_outlined;
        iconColor = Colors.grey[600]!;
    }

    return {
      'icon': iconData,
      'color': iconColor,
    };
  }

  // Format full address
  String formatFullAddress(ShipmentModel shipment) {
    return [
      shipment.streetone,
      shipment.streettwo,
      shipment.city,
      shipment.state,
      shipment.zipCode,
    ]
        .where((part) => part != null && part!.trim().isNotEmpty)
        .join(', ');
  }
}