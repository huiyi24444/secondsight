import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';

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
  String get shortOrderId => orderId.substring(0, 6).toUpperCase();

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

  /// Get status color based on order status
  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'processing':
        return const Color(0xFF8E6CEF);
      case 'completed':
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'shipped':
        return Colors.orange;
      case 'pending_payment':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  /// Get display text for order status
  String getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'pending_payment':
        return 'Pending Payment';
      default:
        return status.toUpperCase();
    }
  }

  /// Check if order is eligible for return/refund
  bool isEligibleForReturn(OrdersModel order) {
    return order.eligibilityForReturn &&
        (order.orderStatus.toLowerCase() == 'completed' ||
            order.orderStatus.toLowerCase() == 'delivered');
  }

  /// Check if order can be rated
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

  /// Submit rating (placeholder for actual implementation)
  Future<bool> submitRating() async {
    if (_rating == 0) return false;

    try {
      // TODO: Implement actual rating submission to Firestore
      // Example implementation:
      // await FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(userId)
      //     .collection('order')
      //     .doc(orderId)
      //     .update({
      //   'rating': _rating,
      //   'review': _reviewController.text.trim(),
      //   'ratedAt': FieldValue.serverTimestamp(),
      // });

      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      resetRatingState();
      return true;
    } catch (e) {
      debugPrint('Error submitting rating: $e');
      return false;
    }
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