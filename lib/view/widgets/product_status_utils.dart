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
}
