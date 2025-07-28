import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../model/cancel_model.dart';
import '../../model/shipment_model.dart';

class OrderDetailsController extends ChangeNotifier {
  final String orderId;
  final String userId;

  OrderDetailsController({
    required this.orderId,
    required this.userId,
  });

  // Rating dialog state
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();

  // Getters
  int get rating => _rating;
  TextEditingController get reviewController => _reviewController;
  String get shortOrderId => orderId.substring(0, 8).toUpperCase();

  /// Get formatted order date
  String formatOrderDate(DateTime orderDate) {
    return DateFormat('MMMM dd, yyyy at HH:mm').format(orderDate);
  }

  /// Get order stream from Firestore
  Stream<DocumentSnapshot> getOrderStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('order')
        .doc(orderId)
        .snapshots();
  }

  /// Get order products stream from Firestore
  Stream<QuerySnapshot> getOrderProductsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('order')
        .doc(orderId)
        .collection('orderProducts')
        .snapshots();
  }

  Future<ShipmentModel?> fetchShipment(String userId, String orderId, String? shipmentId) async {
    if (shipmentId == null) {
      print("Shipment ID is null.");
      return null;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('order')
          .doc(orderId)
          .collection('shipment')
          .doc(shipmentId)
          .get();

      if (!snapshot.exists) {
        print("Shipment document not found.");
        return null;
      }

      final data = snapshot.data();
      if (data == null) {
        print("Shipment data is null.");
        return null;
      }

      return ShipmentModel.fromMap(data, snapshot.id);
    } catch (e) {
      print("Error fetching shipment: $e");
      return null;
    }
  }

  /// Mark order as completed
  Future<bool> markOrderAsCompleted() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('order')
          .doc(orderId)
          .update({
        'orderStatus': 'completed',
        'completedDate': Timestamp.now(),
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error marking order as completed: $e');
      return false;
    }
  }

  /// Check if order should be auto-completed
  Future<void> checkAndAutoCompleteOrder(OrdersModel order) async {
    if (order.orderStatus.toLowerCase() != 'to_receive' || order.toReceiveDate == null) {
      return;
    }

    final currentDate = DateTime.now();
    final daysSinceShipped = currentDate.difference(order.toReceiveDate!).inDays;

    // If more than 10 days have passed since to_receive date, auto-complete the order
    if (daysSinceShipped >= 14) {
      await markOrderAsCompleted();
      debugPrint('Order auto-completed after 14 days');
    }
  }

  /// Check if order is eligible to be marked as received
  bool canMarkAsReceived(OrdersModel order) {
    return order.orderStatus.toLowerCase() == 'to_receive';
  }

  /// Get days remaining until auto-completion
  int getDaysUntilAutoComplete(OrdersModel order) {
    if (order.toReceiveDate == null) return -1;

    final currentDate = DateTime.now();
    final daysSinceShipped = currentDate.difference(order.toReceiveDate!).inDays;
    final remainingDays = 10 - daysSinceShipped;

    return remainingDays > 0 ? remainingDays : 0;
  }





  /// Create OrdersModel from document data
  OrdersModel createOrderFromDocument(DocumentSnapshot doc) {
    return OrdersModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Create OrderProductModel from document data
  OrderProductModel createOrderProductFromDocument(Map<String, dynamic> data) {
    return OrderProductModel.fromJson(data);
  }

  /// Get product document future
  Future<DocumentSnapshot> getProductDocument(DocumentReference? productRef) {
    if (productRef == null) {
      throw ArgumentError('Product reference cannot be null');
    }
    return productRef.get();
  }

  /// Extract product image URL from product data
  String extractProductImageUrl(Map<String, dynamic>? product) {
    if (product == null) return '';

    final productURLList = product['productURL'];
    if (productURLList is List && productURLList.isNotEmpty) {
      return productURLList.first.toString();
    }
    return '';
  }

  /// Extract product name from product data
  String extractProductName(Map<String, dynamic>? product) {
    return product?['productName'] ?? 'Unknown Product';
  }



  // Get order status step configuration
  Map<String, dynamic> getOrderStatusConfig(String orderStatus) {
    final steps = [
      'Confirmed',
      'Preparing',
      'Shipping',
      'Completed'
    ];

    return {
      'title': 'Order Status',
      'steps': steps,
      'currentStep': _getOrderStep(orderStatus),

    };
  }
  int _getOrderStep(String status) {
    switch (status.toLowerCase()) {
      case 'to_ship':
        return 1;
      case 'to_receive':
        return 2;
      case 'completed':
        return 3;
      default:
        return 3;
    }
  }

  String getFormattedDate(DateTime date) {
    return DateFormat('MMMM d, y').format(date); // e.g., June 29, 2025
  }




  /// Check if order is eligible for return/refund
  bool isEligibleForReturn(OrdersModel order) {
    // First check if order status allows returns
    if (order.orderStatus.toLowerCase() != 'completed' &&
        order.orderStatus.toLowerCase() != 'delivered') {
      return false;
    }

    // Check if eligibilityForReturn is already false
    if (!order.eligibilityForReturn) {
      return false;
    }

    // Check if 5 days have passed since completion
    if (order.completedDate != null) {
      final daysSinceCompleted = DateTime.now().difference(order.completedDate!).inDays;
      if (daysSinceCompleted > 5) {
        // Update eligibilityForReturn to false in Firestore
        _updateReturnEligibility(false);
        return false;
      }
    }

    return true;
  }


  /// Update return eligibility in Firestore
  Future<void> _updateReturnEligibility(bool eligible) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('order')
          .doc(orderId)
          .update({
        'eligibilityForReturn': eligible,
      });
    } catch (e) {
      debugPrint('Error updating return eligibility: $e');
    }
  }

  bool canRateOrder(OrdersModel order) {
    return order.orderStatus.toLowerCase() == 'completed' ||
        order.orderStatus.toLowerCase() == 'delivered';
  }

  /// Update rating value
  void updateRating(int newRating) {
    _rating = newRating;
    notifyListeners();
  }

  /// Reset rating dialog state
  void resetRatingState() {
    _rating = 0;
    _reviewController.clear();
    notifyListeners();
  }

  /// Submit rating
  Future<bool> submitRating() async {
    if (_rating == 0) return false;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('order')
          .doc(orderId)
          .update({
        'rating': _rating,
        'review': _reviewController.text.trim(),
        'ratedAt': FieldValue.serverTimestamp(),
      });

      resetRatingState();
      return true;
    } catch (e) {
      debugPrint('Error submitting rating: $e');
      return false;
    }
  }

  showCancelOrderDialog({
    required BuildContext context,
    required String orderId,
    required OrderDetailsController controller,
    required String userId, // Current user ID
    VoidCallback? onCancel,
  }) {
    final reasonController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Cancel Order #$orderId?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please provide a reason for cancellation:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Cancellation Reason *',
                    hintText: 'e.g., Changed mind, Found better price',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes (Optional)',
                    hintText: 'Any additional information',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onCancel?.call();
              },
              child: const Text('Keep Order'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a cancellation reason'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                // Cancel the order
                final success = await controller.cancelOrder(
                  cancelReason: reasonController.text.trim(),
                  cancelNote: noteController.text.trim().isEmpty
                      ? null
                      : noteController.text.trim(),
                  canceledBy: userId,
                );

                // Close loading dialog
                Navigator.of(context).pop();

                if (success) {
                  // Close cancel dialog
                  Navigator.of(context).pop();

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order canceled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Navigate back or refresh
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to cancel order. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Cancel Order'),
            ),
          ],
        );
      },
    );
  }



  Future<bool> cancelOrder({
    required String cancelReason,
    String? cancelNote,
    required String canceledBy,
  }) async {
    try {
      // Create cancellation document reference
      final cancellationRef = FirebaseFirestore.instance
          .collection('cancellation')
          .doc();

      // Prepare cancellation data
      final cancellationData = {
        'orderID': orderId,
        'cancelReason': cancelReason,
        'cancelDate': FieldValue.serverTimestamp(),
        'cancelNote': cancelNote,
        'canceledBy': canceledBy,
      };

      // Use batch write for atomicity
      final batch = FirebaseFirestore.instance.batch();

      // Create cancellation document
      batch.set(cancellationRef, cancellationData);

      // Update order document
      batch.update(
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('order')
            .doc(orderId),
        {
          'orderStatus': 'cancelled',
          'cancelDate': FieldValue.serverTimestamp(),
          'cancelID': cancellationRef.id,
        },
      );

      // Commit batch
      await batch.commit();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error canceling order: $e');
      return false;
    }
  }

  Future<CancellationModel?> getCancellationDetails(String cancelID) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('cancellation')
          .doc(cancelID)
          .get();

      if (!doc.exists) return null;

      return CancellationModel.fromDocument(doc);
    } catch (e) {
      debugPrint('Error fetching cancellation details: $e');
      return null;
    }
  }

// Check if order can be canceled
  bool canCancelOrder(OrdersModel order) {
    // Only allow cancellation for 'to_ship' status
    return order.orderStatus.toLowerCase() == 'to_ship';
  }


  /// Get return eligibility message
  String getReturnIneligibilityMessage() {
    return 'Sorry, this order is no longer eligible for returns. The return period may have expired or the order status doesn\'t allow returns.';
  }

  /// Get success message for rating submission
  String getRatingSuccessMessage() {
    return 'Thank you for rating! ($_rating stars)';
  }

  /// Validate rating before submission
  bool isRatingValid() {
    return _rating > 0;
  }

  /// Get rating button text based on order status
  String getRatingButtonText(OrdersModel order) {
    // You can customize this based on whether the order has already been rated
    return 'Rate Order';
  }

  /// Get return button text based on order status
  String getReturnButtonText(OrdersModel order) {
    return 'Return/Refund';
  }

  /// Check if order has multiple products (for product selection dialog)
  Future<bool> hasMultipleProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('order')
          .doc(orderId)
          .collection('orderProducts')
          .get();

      return snapshot.docs.length > 1;
    } catch (e) {
      debugPrint('Error checking product count: $e');
      return false;
    }
  }

  /// Get formatted total amount
  String getFormattedTotalAmount(double totalAmount) {
    return 'RM ${totalAmount.toStringAsFixed(2)}';
  }

  /// Get formatted product price
  String getFormattedProductPrice(double price) {
    return 'RM ${price.toStringAsFixed(2)}';
  }

  /// Get product quantity text
  String getProductQuantityText(int quantity) {
    return 'Quantity: $quantity';
  }

  /// Get product summary text for product selection
  String getProductSummaryText(int quantity, double price) {
    return 'Qty: $quantity • RM ${price.toStringAsFixed(2)}';
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }


}