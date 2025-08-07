import 'package:flutter/material.dart';

class ProductStatusUtils {
  static Color getProductStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'sold':
        return Colors.orange;
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  static String shortProductId(String id) {
    if (id.length < 12) return id.toUpperCase();
    return id.substring(0, 12).toUpperCase();
  }
}
