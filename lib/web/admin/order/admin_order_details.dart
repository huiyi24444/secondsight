// FILE: order_details_dialog.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:secondsight/view/widgets/order_status_utils.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';


class OrderDetailsDialog {
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

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                width: 700,
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
                            Text('Order #${order.shortOrderId}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Customer: ${customerNames[order.customerId] ?? 'Unknown'}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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
                                items: ['pending', 'processing', 'shipped', 'delivered', 'cancelled']
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
                                      Text(_formatStatus(status)),
                                    ],
                                  ),
                                ))
                                    .toList(),
                                onChanged: (newStatus) async {
                                  if (newStatus != null) {
                                    if (newStatus == 'shipped' && currentStatus != 'shipped') {
                                      final confirmed = await _showShippingConfirmationDialog(context, order, firestore);
                                      if (confirmed) {
                                        setState(() => currentStatus = newStatus);
                                        await updateOrderStatus(order, newStatus, firestore, onOrdersReload, context);
                                      }
                                    } else {
                                      setState(() => currentStatus = newStatus);
                                      await updateOrderStatus(order, newStatus, firestore, onOrdersReload, context);
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

                    _buildOrderInfoRow(order),
                    const SizedBox(height: 20),

                    Text('Products (${products.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
            );
          },
        );
      },
    );
  }

  static String _formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1);
  }

  static Widget _buildOrderInfoRow(OrdersModel order) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoColumn('Order Date', _formatDate(order.orderDate)),
          _verticalDivider(),
          _buildInfoColumn('Payment Status', order.payment ?? 'Pending'),
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
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                  child: details['imageUrl'] != ''
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(details['imageUrl'], fit: BoxFit.cover),
                  )
                      : const Icon(Icons.image, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(details['name'] ?? 'Unknown Product', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('Quantity: ${product.productQuantity}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('RM ${product.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    if (product.productQuantity > 1)
                      Text('RM ${product.price.toStringAsFixed(2)} each', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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

  static Widget _buildDeleteButton(BuildContext context, FirebaseFirestore firestore, OrdersModel order, Future<void> Function() reloadCallback) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Order'),
                content: const Text('Are you sure you want to delete this order?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      Navigator.pop(context);
                      await firestore.collection('users').doc(order.customerId).collection('order').doc(order.id).delete();
                      await reloadCallback();
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

  static Future<bool> _showShippingConfirmationDialog(BuildContext context, OrdersModel order, FirebaseFirestore firestore) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Shipping'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will mark the order as shipped and generate tracking information.'),
            const SizedBox(height: 16),
            Text('A tracking number will be generated and the shipped date will be set to today.', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final trackingNumber = 'SS${DateTime.now().millisecondsSinceEpoch}';
              final shipmentRef = firestore.collection('users').doc(order.customerId).collection('order').doc(order.id).collection('shipment');
              final snapshot = await shipmentRef.get();

              if (snapshot.docs.isNotEmpty) {
                await snapshot.docs.first.reference.update({
                  'trackingNumber': trackingNumber,
                  'shippedDate': Timestamp.now(),
                });
              } else {
                await shipmentRef.add({
                  'trackingNumber': trackingNumber,
                  'shippedDate': Timestamp.now(),
                  'shipAddress': 'Customer Address',
                });
              }

              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            child: const Text('Confirm Shipping'),
          ),
        ],
      ),
    ) ??
        false;
  }

  static Future<void> updateOrderStatus(
      OrdersModel order,
      String newStatus,
      FirebaseFirestore firestore,
      Future<void> Function() reloadCallback,
      BuildContext context,
      ) async {
    try {
      await firestore.collection('users').doc(order.customerId).collection('order').doc(order.id).update({'orderStatus': newStatus});
      await reloadCallback();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order status updated successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating order: $e')));
    }
  }

  static _formatDate(DateTime dateTime) {
    final formatter = DateFormat('dd MMM yyyy');
    return formatter.format(dateTime);
  }
}
