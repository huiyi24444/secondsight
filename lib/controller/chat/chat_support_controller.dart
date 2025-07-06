import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../model/order_model.dart';
import '../../model/conversation_model.dart';
import '../../services/auth_provider.dart';
import '../../view/chat/active_conversation_dialog.dart';

class ChatSupportController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BuildContext context;
  String? _conversationId;
  bool _isLoading = true;
  OrdersModel? _selectedOrder;
  bool _showOrderSelection = true;
  bool _showConversationList = false;
  String? _conversationStatus;

  // Getters
  String? get conversationId => _conversationId;
  bool get isLoading => _isLoading;
  OrdersModel? get selectedOrder => _selectedOrder;
  bool get showOrderSelection => _showOrderSelection;
  bool get showConversationList => _showConversationList;
  String? get conversationStatus => _conversationStatus;

  ChatSupportController(this.context);

  void setLoadingComplete() {
    _isLoading = false;
    notifyListeners();
  }

  void setSelectedOrder(OrdersModel order) {
    _selectedOrder = order;
    notifyListeners();
  }

  void showConversationsList() {
    _showConversationList = true;
    _showOrderSelection = false;
    notifyListeners();
  }

  void showOrderSelectionView() {
    _showConversationList = false;
    _showOrderSelection = true;
    _conversationId = null;
    _conversationStatus = null;
    notifyListeners();
  }

  Future<void> endConversation() async {
    if (_conversationId == null) return;

    try {
      await _firestore.collection('conversations').doc(_conversationId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });

      _conversationStatus = 'ended';
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

  // Check for existing active conversation with the same order ID
  Future<Map<String, dynamic>?> checkExistingActiveConversation(String orderId) async {
    try {
      final userId = Provider.of<AuthProvider>(context, listen: false).userId;
      final existingConversations = await _firestore
          .collection('conversations')
          .where('userId', isEqualTo: userId)
          .where('orderId', isEqualTo: orderId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (existingConversations.docs.isNotEmpty) {
        return {
          'conversationId': existingConversations.docs.first.id,
          'data': existingConversations.docs.first.data(),
        };
      }
      return null;
    } catch (e) {
      print('Error checking existing conversation: $e');
      return null;
    }
  }

  Future<void> startConversation() async {
    if (_selectedOrder == null) return;

    try {
      // Check for existing active conversation with the same order ID
      final existingConversation = await checkExistingActiveConversation(_selectedOrder!.id);

      if (existingConversation != null) {
        // Show dialog to let user choose
        await showActiveConversationDialog(
          context: context,
          orderId: _selectedOrder!.id,
          onContinue: () {
            // Continue with existing conversation
            Navigator.pop(context);
            loadConversation(existingConversation['conversationId']);
          },
          onGoBack: () {
            // Just close the dialog and go back
            Navigator.pop(context);
            // No other action needed - user stays on order selection screen
          },
        );
      } else {
        // No existing active conversation, create new one
        await _createNewConversation();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start conversation')),
      );
    }
  }

  Future<void> _createNewConversation() async {
    if (_selectedOrder == null) return;

    try {
      final userId = Provider.of<AuthProvider>(context, listen: false).userId;
      final conversationRef = await _firestore.collection('conversations').add({
        'userId': userId,
        'orderId': _selectedOrder!.id,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      _conversationId = conversationRef.id;
      _conversationStatus = 'active';
      _showOrderSelection = false;
      notifyListeners();

      // Send automated response
      Future.delayed(const Duration(seconds: 1), () {
        sendMessage(
          'Hello! I\'m connecting you with our customer service team. Someone will be with you shortly.',
          isAdmin: true,
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create conversation')),
      );
    }
  }

  Future<void> loadConversation(String conversationId) async {
    _conversationId = conversationId;
    _showConversationList = false;
    _showOrderSelection = false;
    notifyListeners();

    // Load conversation status
    final conversationDoc = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .get();

    if (conversationDoc.exists) {
      _conversationStatus = conversationDoc.data()?['status'] ?? 'active';
      notifyListeners();
    }
  }

  Future<void> sendMessage(
      String message, {
        bool isAdmin = false,
        bool isSystem = false,
      }) async {
    if (message.trim().isEmpty || _conversationId == null) return;

    if (_conversationStatus == 'ended') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This conversation has ended')),
      );
      return;
    }

    final userId = Provider.of<AuthProvider>(context, listen: false).userId;
    final senderName = isAdmin ? 'Customer Service' : 'You';

    try {
      await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .add({
        'message': message,
        'senderId': isAdmin ? 'admin' : userId,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
        'isAdmin': isAdmin,
        'isSystem': isSystem,
      });

      // Update last message timestamp
      await _firestore.collection('conversations').doc(_conversationId).update({
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  Stream<QuerySnapshot>? getMessagesStream() {
    if (_conversationId == null) return null;

    return _firestore
        .collection('conversations')
        .doc(_conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot> getOrdersStream() {
    final userId = Provider.of<AuthProvider>(context, listen: false).userId;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('order')
        .orderBy('orderDate', descending: true)
        .limit(5)
        .snapshots();
  }

  Stream<QuerySnapshot> getConversationsStream() {
    final userId = Provider.of<AuthProvider>(context, listen: false).userId;
    return _firestore
        .collection('conversations')
        .where('userId', isEqualTo: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  String capitalizeWords(String? text) {
    if (text == null || text.isEmpty) return '';
    return text
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
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
}