// notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // 'order_status', 'chat_message', 'system', 'promotion'
  final String? orderId;
  final String? conversationId;
  final bool isRead;
  final Timestamp createdAt;
  final Map<String, dynamic>? metadata;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.orderId,
    this.conversationId,
    required this.isRead,
    required this.createdAt,
    this.metadata,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'system',
      orderId: data['orderId'],
      conversationId: data['conversationId'],
      isRead: data['isRead'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'orderId': orderId,
      'conversationId': conversationId,
      'isRead': isRead,
      'createdAt': createdAt,
      'metadata': metadata,
    };
  }

  // Helper method to get short order ID
  String get shortOrderId => orderId != null && orderId!.length >= 6
      ? orderId!.substring(0, 6).toUpperCase()
      : orderId ?? '';

  // Helper method to get icon based on type
  IconData getIcon() {
    switch (type) {
      case 'order_status':
        return Icons.shopping_bag;
      case 'chat_message':
        return Icons.chat_bubble;
      case 'promotion':
        return Icons.local_offer;
      case 'system':
      default:
        return Icons.notifications;
    }
  }

  // Helper method to get color based on type
  Color getColor() {
    switch (type) {
      case 'order_status':
        return const Color(0xFF8E6CEF);
      case 'chat_message':
        return Colors.blue;
      case 'promotion':
        return Colors.green;
      case 'system':
      default:
        return Colors.grey;
    }
  }
}