
// small_order_card.dart
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secondsight/view/widgets/order_status_utils.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../../model/user_model.dart';
import 'admin_dashboard_controller.dart';

class SmallOrderCard extends StatefulWidget {
  final OrdersModel order;
  final DocumentSnapshot orderDoc;
  final AdminDashboardController controller;
  final bool isNew;

  const SmallOrderCard({
    super.key,
    required this.order,
    required this.orderDoc,
    required this.controller,
    this.isNew = false,
  });

  @override
  State<SmallOrderCard> createState() => _SmallOrderCardState();
}

class _SmallOrderCardState extends State<SmallOrderCard> {
  late Future<List<OrderProductModel>> _orderProductsFuture;
  CustomerModel? customer;

  @override
  void initState() {
    super.initState();
    _orderProductsFuture = widget.controller.fetchOrderProductsFromOrderDoc(widget.orderDoc);
    _loadCustomerInfo();
  }

  Future<void> _loadCustomerInfo() async {
    if (widget.order.customerId != null) {
      try {
        final customerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.order.customerId)
            .get();

        if (customerDoc.exists && mounted) {
          setState(() {
            customer = CustomerModel.fromJson(customerDoc.data()!, customerDoc.id);
          });
        }
      } catch (e) {
        print('Error loading customer: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer Profile Picture
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
            image: customer?.profilePic.isNotEmpty == true
                ? DecorationImage(
              image: NetworkImage(customer!.profilePic),
              fit: BoxFit.cover,
            )
                : null,
          ),
          child: customer?.profilePic.isEmpty ?? true
              ? Icon(Icons.person, color: Colors.grey[600], size: 20)
              : null,
        ),
        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "Order #${widget.order.shortOrderId}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (widget.isNew) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),

              // Customer Name
              if (customer != null)
                Text(
                  customer!.fullName,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),

              // Order Products Info
              FutureBuilder<List<OrderProductModel>>(
                future: _orderProductsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text(
                      "Loading products...",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    );
                  } else if (snapshot.hasError) {
                    return const Text(
                      "Error loading products",
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text(
                      "No products found",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    );
                  }

                  final products = snapshot.data!;
                  final int totalQuantity = products.fold(0, (sum, p) => sum + p.productQuantity);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${products.length} items • Qty: $totalQuantity',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'RM${widget.order.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Icon(
                  _getPaymentIcon(widget.order.payment),
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(widget.order.orderDate),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: OrderStatusUtils.getStatusColor(widget.order.orderStatus).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: OrderStatusUtils.getStatusColor(widget.order.orderStatus).withOpacity(0.3),
                ),
              ),
              child: Text(
                OrderStatusUtils.formatStatus(widget.order.orderStatus),
                style: TextStyle(
                  color: OrderStatusUtils.getStatusColor(widget.order.orderStatus),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (widget.order.eligibilityForReturn) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.assignment_return,
                  size: 14,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  IconData _getPaymentIcon(String payment) {
    switch (payment.toLowerCase()) {
      case 'mastercard':
        return Icons.credit_card;
      case 'visa':
        return Icons.credit_card;
      case 'paypal':
        return Icons.account_balance_wallet;
      case 'cash':
        return Icons.money;
      default:
        return Icons.payment;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }
  }
