// FILE: order_details_dialog.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:secondsight/view/widgets/order_status_utils.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../../model/shipment_model.dart';
import '../../../model/payment_cards_model.dart';

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
    PaymentCard? paymentCard;
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

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 900,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Enhanced Header with gradient background
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF7C3AED).withOpacity(0.1),
                            const Color(0xFF7C3AED).withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
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
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
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
                                      if (!_isTransitionAllowed(currentStatus, newStatus)) {
                                        _showTransitionError(context, currentStatus, newStatus);
                                        return;
                                      }

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
                                          proceedWithUpdate = true;
                                      }
                                      if (proceedWithUpdate) {
                                        setState(() => currentStatus = newStatus);
                                        await updateOrderStatus(order, newStatus, firestore, onOrdersReload, context);
                                        if (newStatus == 'to_receive') {
                                          await _refreshShipmentData(setState, firestore, order);
                                        }
                                      }
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.pop(context),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.close, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Scrollable content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Enhanced Order Info Cards
                            _buildEnhancedOrderInfoRow(order, paymentCard, context),

                            const SizedBox(height: 24),

                            // Status Timeline Section
                            _buildStatusTimeline(order),

                            if (shipment != null) ...[
                              const SizedBox(height: 24),
                              _buildShipmentInfo(shipment!),
                            ],

                            const SizedBox(height: 24),

                            // Products Section with icon
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 20,
                                    color: Colors.purple,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Products (${products.length})',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildProductList(products, productDetails),

                            const SizedBox(height: 24),

                            // Total Amount Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF7C3AED).withOpacity(0.1),
                                    const Color(0xFF7C3AED).withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF7C3AED).withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C3AED).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.account_balance_wallet,
                                          color: Color(0xFF7C3AED),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Total Amount',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'RM ${order.totalAmount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF7C3AED),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Action Buttons Section
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildDeleteButton(context, firestore, order, onOrdersReload),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  // Enhanced Order Info Row with modern card design
  static Widget _buildEnhancedOrderInfoRow(OrdersModel order, PaymentCard? paymentCard, BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            icon: Icons.calendar_today,
            iconColor: Colors.blue,
            label: 'Order Date',
            value: _formatDate(order.orderDate),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPaymentInfoCard(order, paymentCard, context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.assignment_return,
            iconColor: order.eligibilityForReturn ? Colors.green : Colors.red,
            label: 'Return Eligible',
            value: order.eligibilityForReturn ? 'Yes' : 'No',
            valueColor: order.eligibilityForReturn ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  // Enhanced info card widget
  static Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Enhanced payment info card
  static Widget _buildPaymentInfoCard(OrdersModel order, PaymentCard? paymentCard, BuildContext context) {
    final paymentStatus = order.payment ?? 'Pending';
    final hasPaymentDetails = paymentCard != null;

    return GestureDetector(
      onTap: hasPaymentDetails ? () => _showPaymentDetailsDialog(context, order, paymentCard) : null,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasPaymentDetails ? Colors.blue[50] : Colors.white,
          border: Border.all(color: hasPaymentDetails ? Colors.blue[200]! : Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.payment,
                    size: 18,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Payment Info',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (hasPaymentDetails) ...[
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.blue[600],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              paymentStatus,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: hasPaymentDetails ? Colors.blue[700] : null,
              ),
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

  // Enhanced shipment info section
  static Widget _buildShipmentInfo(ShipmentModel shipment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_shipping,
                size: 20,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Shipment Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildShipmentDetailRow(
                'Tracking Number',
                shipment.trackingNumber?.isNotEmpty ?? false
                    ? shipment.trackingNumber!
                    : 'Not yet provided',
                shipment.trackingNumber?.isNotEmpty ?? false ? null : Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildShipmentDetailRow(
                'Shipped Date',
                shipment.shippedDate != null
                    ? _formatDate(shipment.shippedDate!)
                    : 'Not yet shipped',
                shipment.shippedDate != null ? null : Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildShipmentDetailRow(
                'Recipient',
                shipment.fullName?.isNotEmpty ?? false
                    ? shipment.fullName!
                    : 'Missing name',
                shipment.fullName?.isNotEmpty ?? false ? null : Colors.red,
              ),
              const SizedBox(height: 12),
              _buildShipmentDetailRow(
                'Phone',
                shipment.phoneNum != null && shipment.phoneNum! > 0
                    ? shipment.phoneNum.toString()
                    : 'Missing or invalid number',
                shipment.phoneNum != null && shipment.phoneNum! > 0 ? null : Colors.red,
              ),
              const SizedBox(height: 12),
              _buildShipmentDetailRow(
                'Shipping Address',
                _buildFullAddress(shipment),
                _isAddressValid(shipment) ? null : Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildShipmentDetailRow(String label, String value, Color? valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  static String _buildFullAddress(ShipmentModel shipment) {
    if (_isAddressValid(shipment)) {
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
    return 'Missing or invalid address data';
  }

  static bool _isAddressValid(ShipmentModel shipment) {
    return (shipment.streetone?.isNotEmpty ?? false) &&
        (shipment.city?.isNotEmpty ?? false) &&
        (shipment.state?.isNotEmpty ?? false) &&
        (shipment.zipCode?.isNotEmpty ?? false);
  }

  // Enhanced product list
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Quantity: ${product.productQuantity}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RM ${product.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                    if (product.productQuantity > 1)
                      Text(
                        'RM ${product.price.toStringAsFixed(2)} each',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Enhanced delete button
  static Widget _buildDeleteButton(BuildContext context, FirebaseFirestore firestore,
      OrdersModel order, Future<void> Function() reloadCallback) {
    return TextButton.icon(
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
        _showDeleteConfirmationDialog(context, firestore, order, reloadCallback);
      },
      icon: const Icon(Icons.delete_outline, size: 18),
      label: const Text('Delete Order'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
      ),
    );
  }

  static void _showDeleteConfirmationDialog(BuildContext context, FirebaseFirestore firestore,
      OrdersModel order, Future<void> Function() reloadCallback) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delete Order',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete this order?',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: Colors.red[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Delete Order'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New method to build status timeline
  static Widget _buildStatusTimeline(OrdersModel order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.timeline,
                size: 20,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Order Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: _buildTimelineItems(order),
          ),
        ),
      ],
    );
  }

  // Build timeline items based on order status dates
  static List<Widget> _buildTimelineItems(OrdersModel order) {
    List<Widget> timelineItems = [];

    // Order Created (always present)
    timelineItems.add(_buildTimelineItem(
      'Order Created',
      order.orderDate,
      Icons.shopping_cart,
      Colors.grey[700]!,
      isCompleted: true,
      isFirst: true,
    ));

    // Order Confirmed
    if (order.confirmedDate != null) {
      timelineItems.add(_buildTimelineItem(
        'Order Confirmed',
        order.confirmedDate!,
        Icons.check_circle,
        Colors.grey[700]!,
        isCompleted: true,
      ));
    } else if (order.orderStatus != 'canceled') {
      timelineItems.add(_buildTimelineItem(
        'Order Confirmed',
        null,
        Icons.check_circle_outline,
        Colors.grey[400]!,
        isCompleted: false,
      ));
    }

    // To Ship
    if (order.toShipDate != null) {
      timelineItems.add(_buildTimelineItem(
        'Ready to Ship',
        order.toShipDate!,
        Icons.inventory,
        Colors.grey[700]!,
        isCompleted: true,
      ));
    } else if (['to_ship', 'to_receive', 'completed'].contains(order.orderStatus)) {
      timelineItems.add(_buildTimelineItem(
        'Ready to Ship',
        null,
        Icons.inventory_outlined,
        Colors.grey[400]!,
        isCompleted: false,
      ));
    }

    // To Receive (Shipped)
    if (order.toReceiveDate != null) {
      timelineItems.add(_buildTimelineItem(
        'Shipped',
        order.toReceiveDate!,
        Icons.local_shipping,
        Colors.grey[700]!,
        isCompleted: true,
      ));
    } else if (['to_receive', 'completed'].contains(order.orderStatus)) {
      timelineItems.add(_buildTimelineItem(
        'Shipped',
        null,
        Icons.local_shipping_outlined,
        Colors.grey[400]!,
        isCompleted: false,
      ));
    }

    // Completed or Cancelled
    if (order.completedDate != null) {
      timelineItems.add(_buildTimelineItem(
        'Delivered',
        order.completedDate!,
        Icons.done_all,
        Colors.green[700]!,
        isCompleted: true,
        isLast: true,
      ));
    } else if (order.cancelledDate != null) {
      timelineItems.add(_buildTimelineItem(
        'Cancelled',
        order.cancelledDate!,
        Icons.cancel,
        Colors.red[700]!,
        isCompleted: true,
        isLast: true,
      ));
    } else if (order.orderStatus != 'canceled') {
      timelineItems.add(_buildTimelineItem(
        'Delivered',
        null,
        Icons.done_all_outlined,
        Colors.grey[400]!,
        isCompleted: false,
        isLast: true,
      ));
    }

    // Add last status update info
    timelineItems.add(const SizedBox(height: 16));
    timelineItems.add(Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.update,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            'Last updated: ${_formatDateTime(order.lastStatusUpdate)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    ));

    return timelineItems;
  }

  // Build individual timeline item
  static Widget _buildTimelineItem(
      String title,
      DateTime? date,
      IconData icon,
      Color color, {
        bool isCompleted = false,
        bool isFirst = false,
        bool isLast = false,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            if (!isFirst)
              Container(
                width: 2,
                height: 16,
                color: isCompleted ? Colors.grey[400] : Colors.grey[300],
              ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted ? color : Colors.grey[100],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? color : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isCompleted ? Colors.white : Colors.grey[400],
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: isCompleted ? Colors.grey[400] : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Timeline content
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(top: 4, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.grey[800] : Colors.grey[500],
                  ),
                ),
                if (date != null)
                  Text(
                    _formatDateTime(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  )
                else if (!isCompleted)
                  Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  // New method to show payment details dialog (keeping your existing implementation)
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

  // Rest of your existing methods
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