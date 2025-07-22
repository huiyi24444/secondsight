import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:secondsight/model/product_model.dart';
import 'package:secondsight/view/widgets/product_status_utils.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../../view/widgets/order_status_utils.dart';
// Import your models
// import 'path/to/orders_model.dart';
// import 'path/to/order_product_model.dart';

class OrderDetailsInChat extends StatelessWidget {
  final String orderId;
  final String userId;

  const OrderDetailsInChat({
    Key? key,
    required this.orderId,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4,
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[900],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: Colors.purple[700],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('order')
                    .doc(orderId)
                    .snapshots(),

                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(child: Text('Order not found'));
                  }

                  final orderData = snapshot.data!.data() as Map<String, dynamic>;
                  final order = OrdersModel.fromJson(orderData, orderId);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order Info Section
                        _buildInfoRow('Order ID', '#${order.shortOrderId}'),
                        const SizedBox(height: 12),
                        _buildInfoRow('Date', DateFormat('MMM dd, yyyy').format(order.orderDate)),
                        const SizedBox(height: 12),
                        _buildInfoRow('Status', OrderStatusUtils.formatStatus(order.orderStatus),
                            valueColor: OrderStatusUtils.getStatusColor(order.orderStatus)),
                        const SizedBox(height: 12),
                        _buildInfoRow('Payment', order.payment),
                        const SizedBox(height: 12),
                        _buildShippingRow(),
                        const SizedBox(height: 12),
                        _buildInfoRow('Total Amount', 'RM${order.totalAmount.toStringAsFixed(2)}',
                            valueStyle: const TextStyle(fontWeight: FontWeight.bold)),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Products Section
                        Text(
                          'Order Items',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .collection('order')
                              .doc(orderId)
                              .collection('orderProducts')
                              .snapshots(),
                          builder: (context, productSnapshot) {
                            if (!productSnapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final products = productSnapshot.data!.docs;

                            if (products.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text('No products found'),
                                ),
                              );
                            }

                            return Column(
                              children: products.map((doc) {
                                final productData = doc.data() as Map<String, dynamic>;
                                final product = OrderProductModel.fromJson(productData);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Product SKU: ${ProductStatusUtils.shortProductId(product.productID.id)}',
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Quantity: ${product.productQuantity} × RM${product.price.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'RM${product.totalPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),

                        if (order.eligibilityForReturn) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Eligible for return',
                                  style: TextStyle(color: Colors.green[700]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, TextStyle? valueStyle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: valueStyle ?? TextStyle(
              color: valueColor ?? Colors.grey[800],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildShippingRow({Color? valueColor, TextStyle? valueStyle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            'Shipping Fee:',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            'RM8.00',
            style: valueStyle ?? TextStyle(
              color: valueColor ?? Colors.grey[800],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}