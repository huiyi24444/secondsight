import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../model/order_model.dart';
import '../order/order_details_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'order_status_utils.dart';


class OrderCard extends StatelessWidget {
  final OrdersModel order;
  final String userId;

  const OrderCard({
    super.key,
    required this.order,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM dd, yyyy').format(order.orderDate);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailsView(
              orderId: order.id,
              userId: userId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeader(formattedDate, order.orderStatus),
                  const SizedBox(height: 12),
                  _buildAmountRow(context, order.totalAmount),
                ],
              ),
            ),
            _buildProductPreview(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String formattedDate, String orderStatus) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order #${order.id.substring(0, 6).toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              formattedDate,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: OrderStatusUtils.getStatusColor(orderStatus).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            OrderStatusUtils.getStatusText(orderStatus),
            style: TextStyle(
              color: OrderStatusUtils.getStatusColor(orderStatus),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<int> _fetchTotalQuantity() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('order')
        .doc(order.id)
        .collection('orderProducts')
        .get();

    int totalQuantity = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      totalQuantity += (data['productQuantity'] ?? 1) as int;
    }
    return totalQuantity;
  }

  Widget _buildAmountRow(BuildContext context, double totalAmount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Total: RM ${totalAmount.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        FutureBuilder<int>(
          future: _fetchTotalQuantity(),
          builder: (context, snapshot) {
            final itemCount = snapshot.data ?? 0;
            return Text(
              '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            );
          },
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchProductPreviews() async {
    final orderProductsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('order')
        .doc(order.id)
        .collection('orderProducts')
        .limit(3)
        .get();

    List<Map<String, dynamic>> previews = [];

    for (final doc in orderProductsSnapshot.docs) {
      final data = doc.data();
      final productRef = data['productID'];

      try {
        final productSnap = await productRef.get();
        final productData = productSnap.data() as Map<String, dynamic>?;

        if (productData != null) {
          previews.add({
            'productURL': (productData['productURL'] is List && productData['productURL'].isNotEmpty)
                ? productData['productURL'][0]
                : '',
            'quantity': data['productQuantity'] ?? 1,
          });
        }
      } catch (e) {
        previews.add({
          'productURL': '',
          'quantity': data['productQuantity'] ?? 1,
        });
      }
    }

    return previews;
  }

  Widget _buildProductPreview(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchProductPreviews(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }

          final previews = snapshot.data!;

          return Row(
            children: [
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: previews.length,
                  itemBuilder: (context, index) {
                    final productURL = previews[index]['productURL'];
                    final quantity = previews[index]['quantity'];

                    return Container(
                      width: 56,
                      height: 56,
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: productURL != null && productURL.isNotEmpty
                                ? CachedNetworkImage(
                              imageUrl: productURL,
                              fit: BoxFit.cover,
                              width: 56,
                              height: 56,
                              placeholder: (context, url) => const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 56,
                                height: 56,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            )
                                : Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                          ),
                          if (quantity > 1)
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'x$quantity',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(Icons.chevron_right, color: Colors.grey[400]),
              ),
            ],
          );
        },
      ),
    );
  }

}
