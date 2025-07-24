// FILE: order_details_dialog.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:secondsight/view/widgets/order_status_utils.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../../model/shipment_model.dart';
import '../../../model/payment_cards_model.dart'; // Add this import

class OrderDetailsDialog {
  // Define allowed status transitions
  static const Map<String, List<String>> allowedTransitions = {
    'to_ship': ['to_receive', 'canceled'],
    'to_receive': ['completed', 'canceled'],
    'completed': [], // No transitions allowed
    'canceled': [], // No transitions allowed
  };

  static Future<void> show(
      BuildContext context, {
        required OrdersModel order,
        required List<OrderProductModel> products,
        required Map<String, Map<String, dynamic>> productDetails,
        required Map<String, String> customerNames,
        required FirebaseFirestore firestore,
        required Future<void> Function() onOrdersReload,
      }) async {
    String currentStatus = order.orderStatus;
    print('Fetching shipment for orderId: ${order.id}, customerId: ${order.customerId}');

    // Fetch shipment information
    ShipmentModel? shipment;
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

    // Fetch payment card information
    // Fetch payment card information
    PaymentCard? paymentCard;
    try {
      if (order.payment != null && order.payment != 'Pending') {
        // Try to find the payment method used for this order
        final paymentMethodsSnapshot = await firestore
            .collection('users')
            .doc(order.customerId)
            .collection('paymentMethods')
            .get();

        if (paymentMethodsSnapshot.docs.isNotEmpty) {
          // For now, get the default payment method
          // You might want to store the specific payment method ID used for each order
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

          paymentCard = PaymentCard.fromDocument(defaultPaymentDoc);
        }
      }
    } catch (e) {
      debugPrint('Error fetching payment card: $e');
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                width: 700,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Order #${order.shortOrderId}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Customer: ${customerNames[order.customerId] ?? 'Unknown'}',
                                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButton<String>(
                                  value: currentStatus,
                                  underline: const SizedBox(),
                                  isDense: true,
                                  items: _getAvailableStatuses(currentStatus)
                                      .map((status) => DropdownMenuItem(
                                    value: status,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            color: OrderStatusUtils.getStatusColor(status),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Text(OrderStatusUtils.formatStatus(status)),
                                      ],
                                    ),
                                  ))
                                      .toList(),
                                  onChanged: (newStatus) async {
                                    if (newStatus != null && newStatus != currentStatus) {
                                      // Check if transition is allowed
                                      if (!_isTransitionAllowed(currentStatus, newStatus)) {
                                        _showTransitionError(context, currentStatus, newStatus);
                                        return;
                                      }
                                      // Handle specific transitions
                                      bool proceedWithUpdate = false;
                                      switch ('$currentStatus->$newStatus') {
                                        case 'to_ship->to_receive':
                                          proceedWithUpdate = await _handleShipToReceive(
                                              context, order, shipment, firestore
                                          );
                                          break;
                                        case 'to_receive->completed':
                                          proceedWithUpdate = await _handleReceiveToCompleted(
                                              context, order, firestore
                                          );
                                          break;
                                        case 'to_ship->canceled':
                                        case 'to_receive->canceled':
                                          proceedWithUpdate = await _handleCancellation(
                                              context, order, currentStatus, firestore
                                          );
                                          break;
                                        default:
                                        // For any other allowed transitions
                                          proceedWithUpdate = true;
                                      }
                                      if (proceedWithUpdate) {
                                        setState(() => currentStatus = newStatus);
                                        await updateOrderStatus(order, newStatus, firestore, onOrdersReload, context);
                                        // Refresh shipment data if needed
                                        if (newStatus == 'to_receive') {
                                          await _refreshShipmentData(setState, firestore, order);
                                        }
                                      }
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildOrderInfoRow(order, paymentCard, context), // Pass paymentCard and context
                      if (shipment != null) ...[
                        const SizedBox(height: 20),
                        _buildShipmentInfo(shipment!),
                      ],
                      const SizedBox(height: 20),
                      Text('Products (${products.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _buildProductList(products, productDetails),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      _buildTotalAmount(order),
                      const SizedBox(height: 20),
                      _buildDeleteButton(context, firestore, order, onOrdersReload),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Updated _buildOrderInfoRow to handle payment details
  static Widget _buildOrderInfoRow(OrdersModel order, PaymentCard? paymentCard, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoColumn('Order Date', _formatDate(order.orderDate)),
          _verticalDivider(),
          _buildPaymentStatusColumn(order, paymentCard, context), // Updated payment column
          _verticalDivider(),
          _buildInfoColumn(
            'Return Eligible',
            order.eligibilityForReturn ? 'Yes' : 'No',
            color: order.eligibilityForReturn ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  // New method to build clickable payment status column
  static Widget _buildPaymentStatusColumn(OrdersModel order, PaymentCard? paymentCard, BuildContext context) {
    final paymentStatus = order.payment ?? 'Pending';
    final hasPaymentDetails = paymentCard != null;

    return GestureDetector(
      onTap: hasPaymentDetails ? () => _showPaymentDetailsDialog(context, order, paymentCard) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: hasPaymentDetails ? Colors.blue[50] : null,
          borderRadius: BorderRadius.circular(4),
          border: hasPaymentDetails ? Border.all(color: Colors.blue[200]!) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Info', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  paymentStatus,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: hasPaymentDetails ? Colors.blue[700] : null,
                  ),
                ),
                if (hasPaymentDetails) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.blue[600],
                  ),
                ],
              ],
            ),
            if (hasPaymentDetails)
              Text(
                'Tap for details',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // New method to show payment details dialog
  static void _showPaymentDetailsDialog(BuildContext context, OrdersModel order, PaymentCard paymentCard) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Order information
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #${order.shortOrderId}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getPaymentStatusColor(order.payment ?? 'Pending'),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              order.payment ?? 'Pending',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total Amount: RM ${order.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Payment method information
                const Text(
                  'Payment Method Used',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // Card brand icon
                      _buildCardBrandIcon(paymentCard.brand),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              paymentCard.lastFour.isNotEmpty
                                  ? paymentCard.lastFour
                                  : '${paymentCard.brand.toUpperCase()} Card',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '•••• •••• •••• ${paymentCard.lastFour}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Expires ${paymentCard.expMonth.toString().padLeft(2, '0')}/${paymentCard.expYear.toString().substring(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (paymentCard.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E6CEF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Payment timestamp (if available)
                if (order.orderDate != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Processed',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _formatDateTime(order.orderDate),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8E6CEF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to build card brand icon
  static Widget _buildCardBrandIcon(String brand) {
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

    return Container(
      width: 48,
      height: 36,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  // Helper method to get payment status color
  static Color _getPaymentStatusColor(String status) {
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

  // Helper method to format date and time
  static String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('dd MMM yyyy, HH:mm');
    return formatter.format(dateTime);
  }

  // Rest of your existing methods remain the same...
  static List<String> _getAvailableStatuses(String currentStatus) {
    List<String> statuses = [currentStatus];
    statuses.addAll(allowedTransitions[currentStatus] ?? []);
    return statuses;
  }

  static bool _isTransitionAllowed(String fromStatus, String toStatus) {
    return allowedTransitions[fromStatus]?.contains(toStatus) ?? false;
  }

  static void _showTransitionError(BuildContext context, String fromStatus, String toStatus) {
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

  static Future<bool> _handleShipToReceive(
      BuildContext context,
      OrdersModel order,
      ShipmentModel? shipment,
      FirebaseFirestore firestore,
      ) async {
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
        (shipment.fullName?.isNotEmpty ?? false) &&
        (shipment.phoneNum != null && shipment.phoneNum! > 0) &&
        (shipment.streetone?.isNotEmpty ?? false) &&
        (shipment.city?.isNotEmpty ?? false) &&
        (shipment.state?.isNotEmpty ?? false) &&
        (shipment.zipCode?.isNotEmpty ?? false);

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
      return await _showTrackingNumberDialog(context, order, firestore);
    }
    return true;
  }

  static Future<bool> _handleReceiveToCompleted(
      BuildContext context,
      OrdersModel order,
      FirebaseFirestore firestore,
      ) async {
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

  static Future<bool> _handleCancellation(
      BuildContext context,
      OrdersModel order,
      String currentStatus,
      FirebaseFirestore firestore,
      ) async {
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

  static Future<void> _refreshShipmentData(
      StateSetter setState,
      FirebaseFirestore firestore,
      OrdersModel order,
      ) async {
    try {
      final updatedShipmentSnapshot = await firestore
          .collection('users')
          .doc(order.customerId)
          .collection('order')
          .doc(order.id)
          .collection('shipment')
          .get();
      if (updatedShipmentSnapshot.docs.isNotEmpty) {
        setState(() {
          ShipmentModel.fromMap(
            updatedShipmentSnapshot.docs.first.data(),
            updatedShipmentSnapshot.docs.first.id,
          );
        });
      }
    } catch (e) {
      debugPrint('Error refreshing shipment data: $e');
    }
  }

  static Widget _buildShipmentInfo(ShipmentModel shipment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Shipment Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (shipment.trackingNumber?.isNotEmpty ?? false) ...[
            _buildShipmentRow('Tracking Number', shipment.trackingNumber!),
            const SizedBox(height: 8),
          ] else ...[
            _buildShipmentRow('Tracking Number', 'Not yet provided', valueColor: Colors.orange),
            const SizedBox(height: 8),
          ],
          if (shipment.shippedDate != null) ...[
            _buildShipmentRow('Shipped Date', _formatDate(shipment.shippedDate!)),
            const SizedBox(height: 8),
          ] else ...[
            _buildShipmentRow('Shipped Date', 'Not yet shipped', valueColor: Colors.orange),
            const SizedBox(height: 8),
          ],
          if (shipment.fullName?.isNotEmpty ?? false) ...[
            _buildShipmentRow('Recipient', shipment.fullName!),
            const SizedBox(height: 8),
          ] else ...[
            _buildShipmentRow('Recipient', 'Missing name', valueColor: Colors.red),
            const SizedBox(height: 8),
          ],
          if (shipment.phoneNum != null && shipment.phoneNum! > 0) ...[
            _buildShipmentRow('Phone', shipment.phoneNum.toString()),
            const SizedBox(height: 8),
          ] else ...[
            _buildShipmentRow('Phone', 'Missing or invalid number', valueColor: Colors.red),
            const SizedBox(height: 8),
          ],
          // Full address row in single line
          if ((shipment.streetone?.isNotEmpty ?? false) &&
              (shipment.city?.isNotEmpty ?? false) &&
              (shipment.state?.isNotEmpty ?? false) &&
              (shipment.zipCode?.isNotEmpty ?? false)) ...[
            _buildShipmentRow(
              'Shipping Address',
              [
                shipment.streetone,
                shipment.streettwo,
                shipment.city,
                shipment.state,
                shipment.zipCode,
              ]
                  .where((part) => part != null && part!.trim().isNotEmpty)
                  .join(', '),
            ),
            const SizedBox(height: 8),
          ] else ...[
            _buildShipmentRow(
              'Shipping Address',
              'Missing or invalid address data',
              valueColor: Colors.red,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  static Widget _buildShipmentRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 14, color: valueColor),
          ),
        ),
      ],
    );
  }

  static Widget _buildInfoColumn(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
      ],
    );
  }

  static Widget _verticalDivider() => Container(width: 1, height: 30, color: Colors.grey[300]);

  static Widget _buildProductList(List<OrderProductModel> products, Map<String, Map<String, dynamic>> productDetails) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final productId = (product.productID as DocumentReference).id;
          final details = productDetails[productId] ?? {};
          final imageUrl = details['imageUrl'] as String?;
          final productName = details['name'] as String? ?? 'Unknown Product';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8)
                  ),
                  child: (imageUrl?.isNotEmpty ?? false)
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image, color: Colors.grey),
                    ),
                  )
                      : const Icon(Icons.image, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(productName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('Quantity: ${product.productQuantity}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('RM ${product.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    if (product.productQuantity > 1)
                      Text('RM ${product.price.toStringAsFixed(2)} each',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _buildTotalAmount(OrdersModel order) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Total Amount:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        Text(
          'RM ${order.totalAmount.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
        ),
      ],
    );
  }

  static Widget _buildDeleteButton(BuildContext context, FirebaseFirestore firestore,
      OrdersModel order, Future<void> Function() reloadCallback) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () {
            if (order.orderStatus == 'completed' || order.orderStatus == 'to_receive') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cannot delete ${OrderStatusUtils.formatStatus(order.orderStatus)} orders'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Order'),
                content: const Text('Are you sure you want to delete this order?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      Navigator.pop(context);
                      try {
                        await firestore
                            .collection('users')
                            .doc(order.customerId)
                            .collection('order')
                            .doc(order.id)
                            .delete();
                        await reloadCallback();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error deleting order: $e'))
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          child: const Text('Delete Order', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  static Future<bool> _showTrackingNumberDialog(BuildContext context,
      OrdersModel order, FirebaseFirestore firestore) async {
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

  static Future<void> updateOrderStatus(
      OrdersModel order,
      String newStatus,
      FirebaseFirestore firestore,
      Future<void> Function() reloadCallback,
      BuildContext context,
      ) async {
    try {
      await firestore
          .collection('users')
          .doc(order.customerId)
          .collection('order')
          .doc(order.id)
          .update({'orderStatus': newStatus});
      await reloadCallback();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order status updated successfully'))
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating order: $e'))
        );
      }
    }
  }

  static String _formatDate(DateTime dateTime) {
    final formatter = DateFormat('dd MMM yyyy');
    return formatter.format(dateTime);
  }
}