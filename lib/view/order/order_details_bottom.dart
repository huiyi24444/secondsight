import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/controller/order/notif_controller.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../../view/returnrefund/return_request_view.dart';
import '../../controller/order/order_details_controller.dart';
import 'order_rating_dialog.dart';

class OrderBottomButtons extends StatelessWidget {
  final OrdersModel order;
  final OrderDetailsController controller;
  final String userId;
  final String orderId;

  const OrderBottomButtons({
    Key? key,
    required this.order,
    required this.controller,
    required this.userId,
    required this.orderId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check and auto-complete order if needed
    controller.checkAndAutoCompleteOrder(order);

    final status = order.orderStatus.toLowerCase();

    // Show different button configurations based on order status
    if (status == 'to_receive') {
      return _buildOrderReceivedSection(context);
    } else if (status == 'completed') {
      return _buildCompletedOrderButtons(context);
    }

    // For other statuses, don't show bottom buttons
    return const SizedBox.shrink();
  }

  // Build section for orders waiting to be received
  Widget _buildOrderReceivedSection(BuildContext context) {
    final remainingDays = controller.getDaysUntilAutoComplete(order);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Auto-complete reminder
              if (remainingDays > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.amber[700],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Please confirm once you receive your order',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Auto-completes in $remainingDays day${remainingDays > 1 ? 's' : ''} if not confirmed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber[700],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
                ),

              // Order Received Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _handleOrderReceived(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E6CEF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Order Received',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build buttons for completed orders (your existing code)
  Widget _buildCompletedOrderButtons(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _buildReturnRefundButton(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRateButton(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReturnRefundButton(BuildContext context) {
    final bool isEligible = controller.isEligibleForReturn(order);

    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isEligible
            ? () => _showProductSelectionDialog(context)
            : () => _showIneligibleDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEligible ? Colors.white : Colors.grey[100],
          foregroundColor: isEligible ? Colors.redAccent : Colors.grey[400],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isEligible ? Colors.redAccent : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
        ),
        child: Text(
          controller.getReturnButtonText(order),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isEligible ? Colors.redAccent : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildRateButton(BuildContext context) {
    final bool canRate = controller.canRateOrder(order);

    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: canRate ? () => _handleRate(context) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canRate ? const Color(0xFF8E6CEF) : Colors.grey[300],
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          controller.getRatingButtonText(order),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: canRate ? Colors.white : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  // Handle order received action
  void _handleOrderReceived(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Confirm Order Received',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Have you received your order? This action cannot be undone.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext loadingContext) => const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF8E6CEF),
                  ),
                ),
              );

              // Mark order as completed
              final success = await controller.markOrderAsCompleted();

              // Hide loading indicator
              Navigator.of(context).pop();

              if (success) {
                await NotificationController.createOrderCompletedNotification(
                  customerId: userId, // adjust to your variable
                  orderId: orderId           // adjust to your variable
                );
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Order marked as completed successfully!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              } else {
                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Failed to update order status. Please try again.'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E6CEF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleRate(BuildContext context) {
    showRatingDialog(context: context, order: order);
  }

  Future<void> _showProductSelectionDialog(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return FutureBuilder<Set<String>>(
          future: controller.getSubmittedOrderProductIDs(),
          builder: (context, submittedSnapshot) {
            if (!submittedSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final submittedOrderProductIDs = submittedSnapshot.data!;

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Item to Return',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: controller.getOrderProductsStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFF8E6CEF)),
                        );
                      }

                      final allProducts = snapshot.data!.docs;

                      // Filter products: exclude those with existing return requests
                      final products = allProducts.where((doc) {
                        final orderProductId = doc.id;
                        return !submittedOrderProductIDs.contains(orderProductId);
                      }).toList();

                      if (products.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text('No products available for return.'),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final data = products[index].data() as Map<String, dynamic>;
                          final orderProduct = controller.createOrderProductFromDocument(data);
                          final productRef = orderProduct.productID;
                          final orderProductId = products[index].id;

                          return FutureBuilder<DocumentSnapshot>(
                            future: controller.getProductDocument(productRef),
                            builder: (context, productSnapshot) {
                              if (!productSnapshot.hasData) {
                                return const SizedBox(
                                  height: 60,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF8E6CEF),
                                    ),
                                  ),
                                );
                              }

                              final product = productSnapshot.data!.data() as Map<String, dynamic>?;
                              final productURL = controller.extractProductImageUrl(product);
                              final productName = controller.extractProductName(product);

                              return _buildProductSelectionItem(
                                context,
                                orderProduct,
                                productURL,
                                productName,
                                orderProductId,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildProductSelectionItem(
      BuildContext context,
      OrderProductModel orderProduct,
      String productURL,
      String productName,
      String orderProductId,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.network(
              productURL,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                    size: 20,
                  ),
                );
              },
            ),
          ),
        ),
        title: Text(
          productName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          controller.getProductSummaryText(orderProduct.productQuantity, orderProduct.totalPrice),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF8E6CEF)),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReturnRequestView(
                orderId: orderId,
                userId: userId,
                orderProductId: orderProductId,
              ),
            ),
          );
        },
      ),
    );
  }



  void _showIneligibleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.orange[600], size: 24),
              const SizedBox(width: 8),
              const Text(
                'Return Not Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Text(
            controller.getReturnIneligibilityMessage(),
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8E6CEF),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}