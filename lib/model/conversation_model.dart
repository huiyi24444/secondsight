import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final String userId;
  final String orderId;
  final String status;
  final Timestamp? createdAt;
  final Timestamp? lastMessageAt;
  final Timestamp? endedAt;

  ConversationModel({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.status,
    this.createdAt,
    this.lastMessageAt,
    this.endedAt,
  });

  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ConversationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      orderId: data['orderId'] ?? '',
      status: data['status'] ?? 'active',
      createdAt: data['createdAt'],
      lastMessageAt: data['lastMessageAt'],
      endedAt: data['endedAt'],
    );
  }

  String get shortOrderId =>
      (orderId.length >= 6 ? orderId.substring(0, 6) : orderId).toUpperCase();


  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'orderId': orderId,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'lastMessageAt': lastMessageAt ?? FieldValue.serverTimestamp(),
      if (endedAt != null) 'endedAt': endedAt,
    };
  }
}

class MessageModel {
  final String id;
  final String message;
  final String senderId;
  final String senderName;
  final Timestamp? timestamp;
  final bool isAdmin;
  final bool isSystem;

  MessageModel({
    required this.id,
    required this.message,
    required this.senderId,
    required this.senderName,
    this.timestamp,
    required this.isAdmin,
    required this.isSystem,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      message: data['message'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      timestamp: data['timestamp'],
      isAdmin: data['isAdmin'] ?? false,
      isSystem: data['isSystem'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      'isAdmin': isAdmin,
      'isSystem': isSystem,
    };
  }
}