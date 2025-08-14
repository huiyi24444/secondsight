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
        return 'To Ship';
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
      case 'to_ship':
        return 'To Ship';
      case 'to_receive':
        return 'To Receive';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  static String getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmed';
      case 'to_ship':
        return 'Preparing';
      case 'to_receive':
        return 'In Transit';
      case 'completed':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  static Color getConditionColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'brand_new':
        return Colors.green;
      case 'like_new':
        return Colors.lightGreen;
      case 'good':
        return Colors.orange;
      case 'used':
        return Colors.amber;
      case 'well_worn':
        return Colors.red;
      default:
        return Colors.grey;

    }
  }

  static String formatCondition(String condition) {
    switch (condition.toLowerCase()) {
      case 'brand_new':
        return 'Brand New';
      case 'like_new':
        return 'Like New';
      case 'good':
        return 'Good';
      case 'used':
        return 'Used';
      case 'well_worn':
        return 'Well Worn';
      case 'fair':
        return 'Fair';
      default:
        return condition;

    }
  }


}
