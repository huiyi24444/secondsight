// admin_chat_controller.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../model/conversation_model.dart';
import '../../../model/order_model.dart';
import '../../../view/widgets/user_utils.dart';
import '../login/activity_logger_mixin.dart';

class AdminChatController extends ChangeNotifier with ActivityLoggerMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BuildContext context;

  ConversationModel? _selectedConversation;
  List<ConversationModel> _allConversations = [];
  String _filterStatus = 'all';
  String _searchQuery = '';

  Timer? _searchDebounce;

  ConversationModel? get selectedConversation => _selectedConversation;
  List<ConversationModel> get allConversations => _allConversations;
  String get filterStatus => _filterStatus;

  AdminChatController(this.context);

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> loadConversations() async {
    try {
      final snapshot = await _firestore
          .collection('conversations')
          .orderBy('lastMessageAt', descending: true)
          .get();

      _allConversations = snapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      print('Error loading conversations: $e');

      // Log failed operation
      await logCrud(
        operation: 'read',
        targetType: 'conversation',
        targetId: 'all',
        targetName: 'Load All Conversations',
        isSuccessful: false,
        errorMessage: 'Failed to load conversations: ${e.toString()}',
      );
    }
  }

  void selectConversation(ConversationModel conversation) {
    _selectedConversation = conversation;
    notifyListeners();

    // Log conversation selection (not a CRUD operation, but useful for audit)
    logCrud(
      operation: 'read',
      targetType: 'conversation',
      targetId: conversation.id,
      targetName: 'Conversation with User ${conversation.userId} - Order ${conversation.orderId}',
      changes: {
        'selectedAt': DateTime.now().toIso8601String(),
        'userId': conversation.userId,
        'orderId': conversation.orderId,
        'status': conversation.status,
      },
      isSuccessful: true,
    );
  }

  void setFilterStatus(String status) {
    _filterStatus = status;
    notifyListeners();
  }

  void filterConversations(String query) {
    // Cancel previous timer
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    // Set new timer
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchQuery = query.toLowerCase().trim();
      notifyListeners();
    });
  }

  Stream<List<ConversationModel>> getFilteredConversationsStream() {
    print('[DEBUG] getFilteredConversationsStream called');
    Query query = _firestore.collection('conversations');

    if (_filterStatus != 'all') {
      query = query.where('status', isEqualTo: _filterStatus);
    }

    return query
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      var conversations = snapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc))
          .toList();

      // Apply search filter if needed
      if (_searchQuery.isNotEmpty) {
        List<ConversationModel> filteredConversations = [];

        for (final conv in conversations) {
          bool matches = false;

          // Search by order ID
          if (conv.orderId.toLowerCase().contains(_searchQuery)) {
            matches = true;
          }

          // Search by user ID
          if (!matches && conv.userId.toLowerCase().contains(_searchQuery)) {
            matches = true;
          }

          // Search by short user ID (the displayed format)
          if (!matches) {
            final shortId = shortUserId(conv.userId).toLowerCase();
            if (shortId.contains(_searchQuery)) {
              matches = true;
            }
          }

          // Optional: Search by user details (name, email) - requires additional query
          if (!matches) {
            try {
              final userDoc = await _firestore
                  .collection('users')
                  .doc(conv.userId)
                  .get();

              if (userDoc.exists) {
                final userData = userDoc.data() ?? {};
                final fullName = (userData['fullName'] ?? '').toString().toLowerCase();
                final email = (userData['email'] ?? '').toString().toLowerCase();

                if (fullName.contains(_searchQuery) || email.contains(_searchQuery)) {
                  matches = true;
                }
              }
            } catch (e) {
              print('Error searching user details for ${conv.userId}: $e');
            }
          }

          if (matches) {
            filteredConversations.add(conv);
          }
        }

        return filteredConversations;
      }

      return conversations;
    });
  }

  Stream<QuerySnapshot>? getMessagesStream() {
    if (_selectedConversation == null) return null;

    return _firestore
        .collection('conversations')
        .doc(_selectedConversation!.id)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> sendMessage(String message) async {
    if (_selectedConversation == null || message.trim().isEmpty) return;

    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final conversationName = 'Conversation with User ${_selectedConversation!.userId} - Order ${_selectedConversation!.orderId}';

    try {
      final messageModel = MessageModel(
        id: '',
        message: message,
        senderId: 'admin',
        senderName: 'Customer Service',
        timestamp: null,
        isAdmin: true,
        isSystem: false,
        isRead: false,
      );

      await _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .collection('messages')
          .add(messageModel.toMap());

      // Update last message timestamp
      await _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .update({
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      // Log successful message creation
      await logCrud(
        operation: 'create',
        targetType: 'message',
        targetId: messageId,
        targetName: 'Admin Message in $conversationName',
        changes: {
          'conversationId': _selectedConversation!.id,
          'message': message.length > 50 ? '${message.substring(0, 50)}...' : message,
          'messageLength': message.length,
          'senderId': 'admin',
          'senderName': 'Customer Service',
          'isAdmin': true,
          'sentAt': DateTime.now().toIso8601String(),
        },
        isSuccessful: true,
      );

      // Send notification to user if implemented
      _sendNotificationToUser(_selectedConversation!.userId, message);

    } catch (e) {
      // Log failed message creation
      await logCrud(
        operation: 'create',
        targetType: 'message',
        targetId: messageId,
        targetName: 'Admin Message in $conversationName',
        changes: {
          'conversationId': _selectedConversation!.id,
          'message': message.length > 50 ? '${message.substring(0, 50)}...' : message,
          'messageLength': message.length,
          'senderId': 'admin',
          'senderName': 'Customer Service',
          'isAdmin': true,
          'attemptedAt': DateTime.now().toIso8601String(),
        },
        isSuccessful: false,
        errorMessage: 'Failed to send admin message: ${e.toString()}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  Future<void> endConversation() async {
    if (_selectedConversation == null) return;

    final conversationName = 'Conversation with User ${_selectedConversation!.userId} - Order ${_selectedConversation!.orderId}';
    final previousData = {
      'status': _selectedConversation!.status,
      'endedAt': null,
      'endedBy': null,
    };

    try {
      // Send system message first
      final systemMessage = MessageModel(
        id: '',
        message: 'This conversation has been ended by customer service.',
        senderId: 'system',
        senderName: 'System',
        timestamp: null,
        isAdmin: false,
        isSystem: true,
      );

      await _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .collection('messages')
          .add(systemMessage.toMap());

      // Update conversation status
      await _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'endedBy': 'admin',
      });

      // Log successful conversation termination
      await logCrud(
        operation: 'update',
        targetType: 'conversation',
        targetId: _selectedConversation!.id,
        targetName: conversationName,
        changes: {
          'status': 'ended',
          'endedAt': DateTime.now().toIso8601String(),
          'endedBy': 'admin',
          'systemMessageSent': true,
        },
        previousData: previousData,
        isSuccessful: true,
      );

      // Update local model
      _selectedConversation = ConversationModel(
        id: _selectedConversation!.id,
        userId: _selectedConversation!.userId,
        orderId: _selectedConversation!.orderId,
        status: 'ended',
        createdAt: _selectedConversation!.createdAt,
        lastMessageAt: _selectedConversation!.lastMessageAt,
        endedAt: Timestamp.now(),
      );

      notifyListeners();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation ended')),
      );
    } catch (e) {
      // Log failed conversation termination
      await logCrud(
        operation: 'update',
        targetType: 'conversation',
        targetId: _selectedConversation!.id,
        targetName: conversationName,
        changes: {
          'status': 'ended',
          'endedAt': DateTime.now().toIso8601String(),
          'endedBy': 'admin',
          'attemptedAt': DateTime.now().toIso8601String(),
        },
        previousData: previousData,
        isSuccessful: false,
        errorMessage: 'Failed to end conversation: ${e.toString()}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to end conversation')),
      );
    }
  }

  Future<void> createNewConversation({
    required String userId,
    required String orderId,
  }) async {
    final conversationId = 'conv_${DateTime.now().millisecondsSinceEpoch}';
    final conversationName = 'New Conversation with User $userId - Order $orderId';

    try {
      // Check for existing active conversation
      final existing = await _firestore
          .collection('conversations')
          .where('userId', isEqualTo: userId)
          .where('orderId', isEqualTo: orderId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Log attempt to create duplicate conversation
        await logCrud(
          operation: 'create',
          targetType: 'conversation',
          targetId: conversationId,
          targetName: conversationName,
          changes: {
            'userId': userId,
            'orderId': orderId,
            'status': 'active',
            'attemptedAt': DateTime.now().toIso8601String(),
          },
          isSuccessful: false,
          errorMessage: 'Conversation creation failed: Active conversation already exists for this order',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An active conversation already exists for this order'),
          ),
        );
        return;
      }

      // Create new conversation
      final conversation = ConversationModel(
        id: '',
        userId: userId,
        orderId: orderId,
        status: 'active',
        createdAt: Timestamp.now(),
        lastMessageAt: Timestamp.now(),
      );

      final docRef = await _firestore
          .collection('conversations')
          .add(conversation.toMap());

      // Send initial message
      final initialMessage = MessageModel(
        id: '',
        message: 'Hello! A customer service representative has started a conversation with you. How can we help you today?',
        senderId: 'admin',
        senderName: 'Customer Service',
        timestamp: null,
        isAdmin: true,
        isSystem: false,
      );

      await _firestore
          .collection('conversations')
          .doc(docRef.id)
          .collection('messages')
          .add(initialMessage.toMap());

      // Log successful conversation creation
      await logCrud(
        operation: 'create',
        targetType: 'conversation',
        targetId: docRef.id,
        targetName: conversationName,
        changes: {
          'userId': userId,
          'orderId': orderId,
          'status': 'active',
          'createdAt': DateTime.now().toIso8601String(),
          'createdBy': 'admin',
          'initialMessageSent': true,
        },
        isSuccessful: true,
      );

      // Select the new conversation
      final newConversation = ConversationModel(
        id: docRef.id,
        userId: userId,
        orderId: orderId,
        status: 'active',
        createdAt: Timestamp.now(),
        lastMessageAt: Timestamp.now(),
      );

      selectConversation(newConversation);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New conversation created')),
      );
    } catch (e) {
      // Log failed conversation creation
      await logCrud(
        operation: 'create',
        targetType: 'conversation',
        targetId: conversationId,
        targetName: conversationName,
        changes: {
          'userId': userId,
          'orderId': orderId,
          'status': 'active',
          'attemptedAt': DateTime.now().toIso8601String(),
          'createdBy': 'admin',
        },
        isSuccessful: false,
        errorMessage: 'Failed to create conversation: ${e.toString()}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create conversation')),
      );
    }
  }

  Future<Map<String, dynamic>> getConversationDetails(ConversationModel conversation) async {
    try {
      // Get user details
      print('[DEBUG] Fetching user document for userId: ${conversation.userId}');
      final userDoc = await _firestore
          .collection('users')
          .doc(conversation.userId)
          .get();

      final userData = userDoc.data() ?? {};
      print('[DEBUG] userData: $userData');

      // Get last message
      final messagesSnapshot = await _firestore
          .collection('conversations')
          .doc(conversation.id)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      String lastMessage = '';
      if (messagesSnapshot.docs.isNotEmpty) {
        final messageData = messagesSnapshot.docs.first.data();
        lastMessage = messageData['message'] ?? '';
      }

      // Get unread count (messages not from admin that haven't been read)
      final unreadSnapshot = await _firestore
          .collection('conversations')
          .doc(conversation.id)
          .collection('messages')
          .where('isAdmin', isEqualTo: false)
          .where('isRead', isEqualTo: false)
          .get();

      return {
        'userName': shortUserId(conversation.userId),
        'userEmail': userData['email'] ?? '',
        'fullName': userData['fullName'] ?? 'Unknown User',
        'lastMessage': lastMessage,
        'unreadCount': unreadSnapshot.docs.length,
      };
    } catch (e) {
      print('Error getting conversation details: $e');

      // Log failed operation
      await logCrud(
        operation: 'read',
        targetType: 'conversation',
        targetId: conversation.id,
        targetName: 'Conversation Details - User ${conversation.userId}',
        isSuccessful: false,
        errorMessage: 'Failed to get conversation details: ${e.toString()}',
      );

      return {
        'userName': 'Unknown User',
        'userEmail': '',
        'lastMessage': '',
        'unreadCount': 0,
      };
    }
  }

  Future<void> markMessagesAsRead() async {
    if (_selectedConversation == null) return;

    final conversationName = 'Conversation with User ${_selectedConversation!.userId} - Order ${_selectedConversation!.orderId}';

    try {
      // Get all unread messages not from admin
      final unreadMessages = await _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .collection('messages')
          .where('isAdmin', isEqualTo: false)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadMessages.docs.isEmpty) return;

      // Batch update to mark as read
      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      // Log successful bulk operation
      await logBulk(
        operation: 'update',
        targetType: 'message',
        count: unreadMessages.docs.length,
        details: {
          'action': 'mark_messages_as_read',
          'conversationId': _selectedConversation!.id,
          'conversationName': conversationName,
          'messageIds': unreadMessages.docs.map((doc) => doc.id).toList(),
          'markedReadAt': DateTime.now().toIso8601String(),
          'markedReadBy': 'admin',
        },
      );

    } catch (e) {
      print('Error marking messages as read: $e');

      // Log failed operation using logCrud with correct parameters
      await logCrud(
        operation: 'bulk_update',
        targetType: 'message',
        targetId: 'conversation_${_selectedConversation!.id}',
        targetName: conversationName,
        changes: {
          'action': 'mark_messages_as_read',
          'attemptedAt': DateTime.now().toIso8601String(),
          'status': 'failed',
        },
        isSuccessful: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<List<OrdersModel>> getUserOrders(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('order')
          .orderBy('orderDate', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => OrdersModel.fromJson(
        doc.data(),
        doc.id,
      ))
          .toList();
    } catch (e) {
      print('Error getting user orders: $e');

      // Log failed operation
      await logCrud(
        operation: 'read',
        targetType: 'order',
        targetId: 'user_orders_$userId',
        targetName: 'User Orders for $userId',
        changes: {
          'userId': userId,
          'limit': 10,
          'attemptedAt': DateTime.now().toIso8601String(),
        },
        isSuccessful: false,
        errorMessage: 'Failed to get user orders: ${e.toString()}',
      );

      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      // Search by email (exact match for now, could be enhanced)
      final emailSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: query)
          .limit(5)
          .get();

      final users = emailSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? '',
        };
      }).toList();

      // Log successful user search
      await logCrud(
        operation: 'read',
        targetType: 'user',
        targetId: 'search_$query',
        targetName: 'User Search for "$query"',
        changes: {
          'searchQuery': query,
          'searchType': 'email',
          'resultsCount': users.length,
          'searchedAt': DateTime.now().toIso8601String(),
        },
        isSuccessful: true,
      );

      return users;
    } catch (e) {
      print('Error searching users: $e');

      // Log failed user search
      await logCrud(
        operation: 'read',
        targetType: 'user',
        targetId: 'search_$query',
        targetName: 'User Search for "$query"',
        changes: {
          'searchQuery': query,
          'searchType': 'email',
          'attemptedAt': DateTime.now().toIso8601String(),
        },
        isSuccessful: false,
        errorMessage: 'Failed to search users: ${e.toString()}',
      );

      return [];
    }
  }

  void _sendNotificationToUser(String userId, String message) {
    // Implement push notification logic here
    // This could use Firebase Cloud Messaging or another notification service
    print('Sending notification to user $userId: $message');
  }

  String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  // Get conversation statistics
  Future<Map<String, int>> getConversationStats() async {
    try {
      final snapshot = await _firestore.collection('conversations').get();

      int activeCount = 0;
      int endedCount = 0;
      int todayCount = 0;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'active';

        if (status == 'active') {
          activeCount++;
        } else {
          endedCount++;
        }

        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && createdAt.isAfter(todayStart)) {
          todayCount++;
        }
      }

      // Log successful stats retrieval
      await logCrud(
        operation: 'read',
        targetType: 'conversation',
        targetId: 'statistics',
        targetName: 'Conversation Statistics',
        changes: {
          'activeCount': activeCount,
          'endedCount': endedCount,
          'todayCount': todayCount,
          'totalCount': snapshot.docs.length,
          'retrievedAt': DateTime.now().toIso8601String(),
        },
        isSuccessful: true,
      );

      return {
        'active': activeCount,
        'ended': endedCount,
        'today': todayCount,
        'total': snapshot.docs.length,
      };
    } catch (e) {
      print('Error getting stats: $e');

      // Log failed stats retrieval
      await logCrud(
        operation: 'read',
        targetType: 'conversation',
        targetId: 'statistics',
        targetName: 'Conversation Statistics',
        changes: {
          'attemptedAt': DateTime.now().toIso8601String(),
        },
        isSuccessful: false,
        errorMessage: 'Failed to get conversation statistics: ${e.toString()}',
      );

      return {
        'active': 0,
        'ended': 0,
        'today': 0,
        'total': 0,
      };
    }
  }
}