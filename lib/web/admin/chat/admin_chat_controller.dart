// admin_chat_controller.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../model/conversation_model.dart';
import '../../../model/order_model.dart';
import '../../../view/widgets/user_utils.dart';

class AdminChatController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BuildContext context;

  ConversationModel? _selectedConversation;
  List<ConversationModel> _allConversations = [];
  String _filterStatus = 'all';
  String _searchQuery = '';

  ConversationModel? get selectedConversation => _selectedConversation;
  List<ConversationModel> get allConversations => _allConversations;
  String get filterStatus => _filterStatus;

  AdminChatController(this.context);

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
    }
  }

  void selectConversation(ConversationModel conversation) {
    _selectedConversation = conversation;
    notifyListeners();
  }

  void setFilterStatus(String status) {
    _filterStatus = status;
    notifyListeners();
  }

  void filterConversations(String query) {
    _searchQuery = query.toLowerCase();
    notifyListeners();
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
        .map((snapshot) {
      var conversations = snapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc))
          .toList();

      // Apply search filter if needed
      if (_searchQuery.isNotEmpty) {
        conversations = conversations.where((conv) {
          // This would need to be enhanced to search by user name
          // For now, searching by order ID
          return conv.orderId.toLowerCase().contains(_searchQuery);
        }).toList();
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

    try {
      final messageModel = MessageModel(
        id: '',
        message: message,
        senderId: 'admin',
        senderName: 'Customer Service',
        timestamp: null,
        isAdmin: true,
        isSystem: false,
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

      // Send notification to user if implemented
      _sendNotificationToUser(_selectedConversation!.userId, message);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  Future<void> endConversation() async {
    if (_selectedConversation == null) return;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to end conversation')),
      );
    }
  }

  Future<void> createNewConversation({
    required String userId,
    required String orderId,
  }) async {
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

    try {
      // Get all unread messages not from admin
      final unreadMessages = await _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .collection('messages')
          .where('isAdmin', isEqualTo: false)
          .where('isRead', isEqualTo: false)
          .get();

      // Batch update to mark as read
      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
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

      // Could add more search logic here (by name, etc.)

      return users;
    } catch (e) {
      print('Error searching users: $e');
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

      return {
        'active': activeCount,
        'ended': endedCount,
        'today': todayCount,
        'total': snapshot.docs.length,
      };
    } catch (e) {
      print('Error getting stats: $e');
      return {
        'active': 0,
        'ended': 0,
        'today': 0,
        'total': 0,
      };
    }
  }
}