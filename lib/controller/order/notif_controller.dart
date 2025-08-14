// notification_controller.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../model/notif_model.dart';
import '../../model/order_model.dart';
import '../../view/chat/chat_order_selection.dart';
import '../../view/order/order_details_view.dart';
import '../../view/widgets/product_status_utils.dart';
import '../chat/chat_support_controller.dart';

class NotificationController extends ChangeNotifier {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  NotificationController({required this.userId});

  // Stream of all notifications for the user
  Stream<QuerySnapshot> getNotificationsStream() {
    print('Getting notifications stream for user: $userId');
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Stream of unread notification count
  Stream<int> getUnreadCountStream() {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final batch = _firestore.batch();
      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // Delete single notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing all notifications: $e');
    }
  }

  // Create a new notification (for testing or admin use)
  Future<void> createNotification({
    required String title,
    required String message,
    required String type,
    String? orderId,
    String? conversationId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'orderId': orderId,
        'conversationId': conversationId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  // Handle notification tap
  void handleNotificationTap(BuildContext context, NotificationModel notification) async {
    // Mark as read when tapped
    await markAsRead(notification.id);

    // Navigate based on notification type
    switch (notification.type) {
      case 'order_status':
        if (notification.orderId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailsView(
                orderId: notification.orderId!,
                userId: userId,
              ),
            ),
          );
        }
        break;
      case 'chat_message':
        if (notification.conversationId != null && notification.orderId != null) {
          // Create and initialize the chat controller
          final chatController = ChatSupportController(context);

          // Initialize with notification data
          await chatController.initializeFromNotification(
            conversationId: notification.conversationId!,
            orderId: notification.orderId!,
            userId: userId,
          );

          // Navigate to chat support view with preloaded controller
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatOrderSelection(
                  //preloadedController: chatController,
                ),
              ),
            );
          }
        }
        break;
      default:
      // For other types, just mark as read
        break;
    }
  }

  // Format time ago
  String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }


  static Future<void> createOrderConfirmationNotification({
    required String userId,
    required String orderId,
    required double totalAmount,
    required int itemCount,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': 'Order Confirmed',
        'message': 'Your order #${orderId.substring(0, 6).toUpperCase()} for ${itemCount} item${itemCount > 1 ? 's' : ''} (RM${totalAmount.toStringAsFixed(2)}) has been confirmed and is being prepared.',
        'type': 'order_status',
        'orderId': orderId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'orderStatus': 'to_ship',
          'totalAmount': totalAmount,
          'itemCount': itemCount,
        },
      });
    } catch (e) {
      debugPrint('Error creating order confirmation notification: $e');
      // Don't throw error here as it shouldn't prevent order completion
    }
  }

  static Future<void> createOrderShipmentNotification({
    required String userId,
    required String orderId,
    required double totalAmount,
    required int itemCount,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': 'Order Shipped',
        'message': 'Your order #${orderId.substring(0, 6).toUpperCase()} for ${itemCount} item${itemCount > 1 ? 's' : ''} (RM${totalAmount.toStringAsFixed(2)}) has been shipped.',
        'type': 'order_status',
        'orderId': orderId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'orderStatus': 'to_receive',
          'totalAmount': totalAmount,
          'itemCount': itemCount,
        },
      });
    } catch (e) {
      debugPrint('Error creating order confirmation notification: $e');
      // Don't throw error here as it shouldn't prevent order completion
    }
  }

  /// Create delivery notification
  static Future<void> createOrderCompletedNotification({
    required String customerId,
    required String orderId,
  }) async {
   try{
     await FirebaseFirestore.instance.collection('notifications').add({
       'userId': customerId,
       'title': 'Order Delivered',
       'message': 'Your order #${orderId.substring(0, 6).toUpperCase()} has been delivered. Thank you for shopping with us!',
       'type': 'order_status',
       'orderId': orderId,
       'isRead': false,
       'createdAt': FieldValue.serverTimestamp(),
       'metadata': {
         'orderStatus': 'delivered',
         'showReview': true, // Can be used to show review prompt
       },
     });
   }catch(e){
     debugPrint('Error creating order completed notification: $e');
   }
  }

  static Future<void> createOrderCancellationNotification({
    required String customerId,
    required String orderId,
    required String cancellationReason,
    String? cancelNote,
  }) async {
    try {
      // Create cancellation notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': customerId,
        'title': 'Order Cancelled',
        'message': 'Your order #${orderId.substring(0, 6).toUpperCase()} has been cancelled. Refund will be processed within 3-5 business days.',
        'type': 'order_status',
        'orderId': orderId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'orderStatus': 'cancelled',
          'cancellationReason': cancellationReason,
          'refundExpected': true,
        },
      });
    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }

  static Future<void> createReturnNotification({
    required String returnId,
    required String newStatus,
    required String userId,
    required String productId,
    String? orderId,
  }) async {
    try {
      // 🔍 DEBUG: Log all parameters
      debugPrint('🔔 [NOTIFICATION] Creating return notification:');
      debugPrint('   - returnId: $returnId');
      debugPrint('   - newStatus: $newStatus');
      debugPrint('   - userId: $userId');
      debugPrint('   - productId: $productId');
      debugPrint('   - orderId: $orderId');

      String title = '';
      String message = '';

      switch (newStatus.toLowerCase()) {
        case 'approved':
          title = 'Return Request Approved';
          message = 'Your return request for product #${ProductStatusUtils.shortProductId(productId)} has been approved. Please ship the items back using the provided instructions.';
          break;

        case 'rejected':
          title = 'Return Request Rejected';
          message = 'Your return request for product #${ProductStatusUtils.shortProductId(productId)} has been rejected. Please contact support for more information.';
          break;

        case 'pending_inspection':
          title = 'Items Received';
          message = 'We have received your returned items for product #${ProductStatusUtils.shortProductId(productId)}. Our team is now inspecting them.';
          break;

        case 'completed_inspection':
          title = 'Inspection Completed';
          message = 'Inspection completed for your return of product #${ProductStatusUtils.shortProductId(productId)}. Processing your refund now.';
          break;

        case 'refunded':
          title = 'Refund Processed';
          message = 'Your refund for product #${ProductStatusUtils.shortProductId(productId)} has been processed. It should appear in your account within 3-5 business days.';
          break;

        case 'not_refunded':
          title = 'Refund Unsuccessful';
          message = 'We were unable to process the refund for product #${ProductStatusUtils.shortProductId(productId)}. Please contact support.';
          break;

        case 'completed':
          title = 'Return Completed';
          message = 'Your return for product #${ProductStatusUtils.shortProductId(productId)} has been completed successfully.';
          break;

        case 'cancelled':
          title = 'Return Cancelled';
          message = 'Your return request for product #${ProductStatusUtils.shortProductId(productId)} has been cancelled.';
          break;

        case 'pending_approval':
          title = 'Return Request Submitted';
          message = 'Your return request for product #${ProductStatusUtils.shortProductId(productId)} has been submitted and is pendinggg approval.';
          break;

        default:
          title = 'Return Update';
          message = 'Your return request status has been updated to $newStatus for product #${ProductStatusUtils.shortProductId(productId)}.';
      }

      // 🔍 DEBUG: Log notification content
      debugPrint('📝 [NOTIFICATION] Title: $title');
      debugPrint('📝 [NOTIFICATION] Message: $message');

      final notificationData = {
        'userId': userId,
        'title': title,
        'message': message,
        'type': 'return_status',
        'orderId': orderId,
        'productId': productId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'returnId': returnId,
          'returnStatus': newStatus,
          'productId': productId,
          'orderId': orderId,
        },
      };

      // 🔍 DEBUG: Log notification data
      debugPrint('💾 [FIRESTORE] Writing notification data: $notificationData');

      final docRef = await FirebaseFirestore.instance
          .collection('notifications')
          .add(notificationData);

      debugPrint('✅ [SUCCESS] Return notification created with ID: ${docRef.id}');
      debugPrint('   - For user: $userId');
      debugPrint('   - Status: $newStatus');
      debugPrint('   - Return ID: $returnId');

    } catch (e, stackTrace) {
      debugPrint('❌ [ERROR] Failed to create return notification: $e');
      debugPrint('📋 [STACK] $stackTrace');

      // Check specific error types
      if (e.toString().contains('permission')) {
        debugPrint('🔒 [PERMISSION] Check Firestore security rules for notifications collection');
      }
      if (e.toString().contains('network')) {
        debugPrint('🌐 [NETWORK] Check internet connection');
      }

      // ⚠️ IMPORTANT: Rethrow the error so we can see it in the admin controller
      rethrow;
    }
  }





  // Create chat message notification
  static Future<void> createChatNotification({
    required String userId,
    required String conversationId,
    required String orderId,
    required String senderName,
    String? lastMessage,
  }) async {
    // Don't create notification if the user is currently in the chat
    // You can implement this check based on your app's navigation state

    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'title': 'New Message from $senderName',
      'message': lastMessage ?? 'You have a new message regarding order #${orderId.substring(0, 6).toUpperCase()}',
      'type': 'chat_message',
      'orderId': orderId,
      'conversationId': conversationId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': {
        'senderName': senderName,
        'lastMessage': lastMessage,
      },
    });
  }



}