import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import 'admin_dashboard_controller.dart';

class SmallOrderCard extends StatefulWidget {
  final OrdersModel order;
  final DocumentSnapshot orderDoc;
  final AdminDashboardController controller;

  const SmallOrderCard({
    super.key,
    required this.order,
    required this.orderDoc,
    required this.controller,
  });

  @override
  State<SmallOrderCard> createState() => _SmallOrderCardState();
}

class _SmallOrderCardState extends State<SmallOrderCard> {
  late Future<List<OrderProductModel>> _orderProductsFuture;

  @override
  void initState() {
    super.initState();
    _orderProductsFuture = widget.controller.fetchOrderProductsFromOrderDoc(widget.orderDoc);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.image, color: Colors.grey),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Order #${widget.order.shortOrderId}", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              FutureBuilder<List<OrderProductModel>>(
                future: _orderProductsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text("Loading products...");
                  } else if (snapshot.hasError) {
                    return const Text("Error loading products");
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text("No products found");
                  }

                  final products = snapshot.data!;
                  final int totalQuantity = products.fold(0, (sum, p) => sum + p.productQuantity);
                  final double totalAmount =
                  products.fold(0.0, (sum, p) => sum + (p.productQuantity * p.price));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Quantity: $totalQuantity',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                      Text(
                        'Total Amount: RM${totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
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
            Text(
              _formatDate(widget.order.orderDate),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(widget.order.orderStatus),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(widget.order.orderStatus,
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return Colors.orange;
      case "completed":
        return Colors.green;
      case "cancelled":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
