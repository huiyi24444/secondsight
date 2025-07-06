import 'package:flutter/material.dart';

class OrderStatusUtils {
  /// Get status color based on order status
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'to_ship':
        return const Color(0xFF8E6CEF);
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'to_receive':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Get display text for order status
  static String getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'to_ship':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'to_receive':
        return 'Shipped';
      default:
        return status.toUpperCase();
    }
  }

  static String formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
