// lib/widgets/order_card.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../order/order_details_view.dart';

class OrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final String userId;

  const OrderCard({
    super.key,
    required this.orderId,
    required this.orderData,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final orderDate = (orderData['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final formattedDate = DateFormat('MMM dd, yyyy').format(orderDate);
    final totalAmount = (orderData['totalAmount'] ?? 0).toDouble();
    final orderStatus = orderData['orderStatus'] ?? 'processing';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailsView(
              orderId: orderId,
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
                  _buildHeader(formattedDate, orderStatus),
                  const SizedBox(height: 12),
                  _buildAmountRow(context, totalAmount),
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
              'Order #${orderId.substring(0, 6).toUpperCase()}',
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
            color: _getStatusColor(orderStatus).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _getStatusText(orderStatus),
            style: TextStyle(
              color: _getStatusColor(orderStatus),
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
        .doc(orderId)
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
        .collection('order') // 🔁 singular
        .doc(orderId)
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
                                ? Image.network(
                              productURL,
                              fit: BoxFit.cover,
                              width: 56,
                              height: 56,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                          (loadingProgress.expectedTotalBytes ?? 1)
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Container(
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


  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
        return Colors.orange;
      case 'processing':
        return const Color(0xFF8E6CEF);
      case 'shipped':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'returned':
        return Colors.amber;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
        return 'To Pay';
      case 'processing':
        return 'To Ship';
      case 'shipped':
        return 'To Receive';
      case 'completed':
        return 'Completed';
      case 'returned':
        return 'Returned';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
