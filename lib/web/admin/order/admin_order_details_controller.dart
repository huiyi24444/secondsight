// FILE: order_details_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secondsight/view/widgets/order_status_utils.dart';
import '../../../model/order_model.dart';
import '../../../model/shipment_model.dart';
import '../../../model/payment_cards_model.dart';

class OrderDetailsController extends ChangeNotifier {
  final OrdersModel order;
  final FirebaseFirestore firestore;
  final Future<void> Function() onOrdersReload;

  late String currentStatus;
  ShipmentModel? shipment;
  PaymentCard? paymentCard;
  bool isLoading = true;

  // Define allowed status transitions
  static const Map<String, List<String>> allowedTransitions = {
    'to_ship': ['to_receive', 'canceled'],
    'to_receive': ['completed', 'canceled'],
    'completed': [],
    'canceled': [],
  };

  OrderDetailsController({
    required this.order,
    required this.firestore,
    required this.onOrdersReload,
  }) {
    currentStatus = order.orderStatus;
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    await Future.wait([
      _fetchShipmentData(),
      _fetchPaymentData(),
    ]);
    isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchShipmentData() async {
    try {
      final shipmentSnapshot = await firestore
          .collection('users')
          .doc(order.customerId)
          .collection('order')
          .doc(order.id)
          .collection('shipment')
          .get();
      if (shipmentSnapshot.docs.isNotEmpty) {
        shipment = ShipmentModel.fromMap(
          shipmentSnapshot.docs.first.data(),
          shipmentSnapshot.docs.first.id,
        );
      }
    } catch (e) {
      debugPrint('Error fetching shipment: $e');
    }
  }

  Future<void> _fetchPaymentData() async {
    try {
      if (order.payment != null && order.payment != 'Pending') {
        final paymentMethodsSnapshot = await firestore
            .collection('users')
            .doc(order.customerId)
            .collection('paymentMethods')
            .get();

        if (paymentMethodsSnapshot.docs.isNotEmpty) {
          QueryDocumentSnapshot<Map<String, dynamic>>? defaultPaymentDoc;

          for (var doc in paymentMethodsSnapshot.docs) {
            if (doc.data()['isDefault'] == true) {
              defaultPaymentDoc = doc;
              break;
            }
          }

          defaultPaymentDoc ??= paymentMethodsSnapshot.docs.first;
          paymentCard = PaymentCard.fromDocument(defaultPaymentDoc);
        }
      }
    } catch (e) {
      debugPrint('Error fetching payment card: $e');
    }
  }

  Future<void> handleStatusChange(String? newStatus, BuildContext context) async {
    if (newStatus != null && newStatus != currentStatus) {
      if (!isTransitionAllowed(currentStatus, newStatus)) {
        showTransitionError(currentStatus, newStatus, context);
        return;
      }

      bool proceedWithUpdate = false;
      switch ('$currentStatus->$newStatus') {
        case 'to_ship->to_receive':
          proceedWithUpdate = await handleShipToReceive(context);
          break;
        case 'to_receive->completed':
          proceedWithUpdate = await handleReceiveToCompleted(context);
          break;
        case 'to_ship->canceled':
        case 'to_receive->canceled':
          proceedWithUpdate = await handleCancellation(context);
          break;
        default:
          proceedWithUpdate = true;
      }

      if (proceedWithUpdate) {
        currentStatus = newStatus;
        notifyListeners();
        await updateOrderStatus(newStatus, context);
        if (newStatus == 'to_receive') {
          await _fetchShipmentData();
          notifyListeners();
        }
      }
    }
  }

  Future<void> updateOrderStatus(String newStatus, BuildContext context) async {
    try {
      await firestore
          .collection('users')
          .doc(order.customerId)
          .collection('order')
          .doc(order.id)
          .update({'orderStatus': newStatus});
      await onOrdersReload();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order status updated successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating order: $e')),
        );
      }
    }
  }

  Future<bool> handleShipToReceive(BuildContext context) async {
    if (order.payment == null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Payment Not Confirmed'),
          content: const Text(
              'This order does not have a recorded payment method. Are you sure you want to ship it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      ) ?? false;
      if (!proceed) return false;
    }

    bool isAddressComplete = shipment != null &&
        (shipment!.fullName?.isNotEmpty ?? false) &&
        (shipment!.phoneNum != null && shipment!.phoneNum! > 0) &&
        (shipment!.streetone?.isNotEmpty ?? false) &&
        (shipment!.city?.isNotEmpty ?? false) &&
        (shipment!.state?.isNotEmpty ?? false) &&
        (shipment!.zipCode?.isNotEmpty ?? false);

    if (!isAddressComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shipping address is incomplete. Please update customer information first.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (shipment?.trackingNumber == null || shipment!.trackingNumber!.isEmpty) {
      return await showTrackingNumberDialog(context);
    }
    return true;
  }

  Future<bool> handleReceiveToCompleted(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mark this order as completed?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. The order will be marked as delivered.',
                      style: TextStyle(fontSize: 13, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await firestore
                  .collection('users')
                  .doc(order.customerId)
                  .collection('order')
                  .doc(order.id)
                  .update({
                'completedDate': Timestamp.now(),
              });
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete Order'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> handleCancellation(BuildContext context) async {
    final reasonController = TextEditingController();
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentStatus == 'to_receive')
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This order has already been shipped. Cancellation may require return shipping.',
                        style: TextStyle(fontSize: 13, color: Colors.red[900]),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason *',
                hintText: 'Enter reason for cancellation',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a cancellation reason')),
                );
                return;
              }
              await firestore
                  .collection('users')
                  .doc(order.customerId)
                  .collection('order')
                  .doc(order.id)
                  .update({
                'cancellationReason': reasonController.text.trim(),
                'canceledDate': Timestamp.now(),
              });
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> showTrackingNumberDialog(BuildContext context) async {
    final trackingNumberController = TextEditingController();
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Tracking Number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A tracking number is required to update the status to "To Receive".',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: trackingNumberController,
              decoration: const InputDecoration(
                labelText: 'Tracking Number *',
                hintText: 'Enter tracking number',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'The shipped date will be set to current date/time.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (trackingNumberController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a tracking number')),
                );
                return;
              }
              try {
                final shipmentRef = firestore
                    .collection('users')
                    .doc(order.customerId)
                    .collection('order')
                    .doc(order.id)
                    .collection('shipment');
                final snapshot = await shipmentRef.get();
                final updateData = {
                  'trackingNumber': trackingNumberController.text.trim(),
                  'shippedDate': Timestamp.now(),
                };
                if (snapshot.docs.isNotEmpty) {
                  await snapshot.docs.first.reference.update(updateData);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shipment document not found')),
                  );
                  Navigator.pop(context, false);
                  return;
                }
                if (context.mounted) {
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating tracking number: $e')),
                  );
                  Navigator.pop(context, false);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> deleteOrder(BuildContext context) async {
    try {
      await firestore
          .collection('users')
          .doc(order.customerId)
          .collection('order')
          .doc(order.id)
          .delete();
      await onOrdersReload();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting order: $e'))
        );
      }
    }
  }

  void checkDeletePermission(BuildContext context) {
    if (order.orderStatus == 'completed' || order.orderStatus == 'to_receive') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete ${OrderStatusUtils.formatStatus(order.orderStatus)} orders'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<String> getAvailableStatuses(String currentStatus) {
    List<String> statuses = [currentStatus];
    statuses.addAll(allowedTransitions[currentStatus] ?? []);
    return statuses;
  }

  bool isTransitionAllowed(String fromStatus, String toStatus) {
    return allowedTransitions[fromStatus]?.contains(toStatus) ?? false;
  }

  void showTransitionError(String fromStatus, String toStatus, BuildContext context) {
    String message = '';
    if (fromStatus == 'completed') {
      message = 'Completed orders cannot be modified.';
    } else if (fromStatus == 'canceled') {
      message = 'Canceled orders cannot be reactivated.';
    } else if (fromStatus == 'to_receive' && toStatus == 'to_ship') {
      message = 'Cannot revert to "To Ship" once tracking number is provided.';
    } else {
      message = 'This status transition is not allowed.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}