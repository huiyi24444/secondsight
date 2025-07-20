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
  ConversationModel? _currentConversation; // Use ConversationModel instead of separate fields
  bool _isLoading = true;
  OrdersModel? _selectedOrder;
  bool _showOrderSelection = true;
  bool _showConversationList = false;

  // Updated getters to use ConversationModel
  String? get conversationId => _currentConversation?.id;
  bool get isLoading => _isLoading;
  OrdersModel? get selectedOrder => _selectedOrder;
  bool get showOrderSelection => _showOrderSelection;
  bool get showConversationList => _showConversationList;
  String? get conversationStatus => _currentConversation?.status;
  ConversationModel? get currentConversation => _currentConversation;

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
    _currentConversation = null;
    notifyListeners();
  }

  Future<void> endConversation() async {
    if (_currentConversation == null) return;

    try {
      await _firestore.collection('conversations').doc(_currentConversation!.id).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });

      // Update the local conversation model
      _currentConversation = ConversationModel(
        id: _currentConversation!.id,
        userId: _currentConversation!.userId,
        orderId: _currentConversation!.orderId,
        status: 'ended',
        createdAt: _currentConversation!.createdAt,
        lastMessageAt: _currentConversation!.lastMessageAt,
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

  // Updated to return ConversationModel
  Future<ConversationModel?> checkExistingActiveConversation(String orderId) async {
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
        return ConversationModel.fromFirestore(existingConversations.docs.first);
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
            _currentConversation = existingConversation;
            _showOrderSelection = false;
            notifyListeners();
          },
          onGoBack: () {
            // Just close the dialog and go back
            Navigator.pop(context);
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

      // Check if userId is null
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      // Create the conversation model first
      final newConversation = ConversationModel(
        id: '', // Will be set after creation
        userId: userId,
        orderId: _selectedOrder!.id,
        status: 'active',
        createdAt: Timestamp.now(),
        lastMessageAt: Timestamp.now(),
      );

      // Add to Firestore
      final conversationRef = await _firestore.collection('conversations').add(newConversation.toMap());

      // Update with the actual ID
      _currentConversation = ConversationModel(
        id: conversationRef.id,
        userId: newConversation.userId,
        orderId: newConversation.orderId,
        status: newConversation.status,
        createdAt: newConversation.createdAt,
        lastMessageAt: newConversation.lastMessageAt,
      );

      _showOrderSelection = false;
      notifyListeners();

      // Send automated response using MessageModel
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
    try {
      _showConversationList = false;
      _showOrderSelection = false;

      // Load conversation using the model
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (conversationDoc.exists) {
        _currentConversation = ConversationModel.fromFirestore(conversationDoc);

        // Load the associated order if needed
        if (_currentConversation != null && _selectedOrder == null) {
          // You might want to load the order data here
          // based on _currentConversation.orderId
        }

        notifyListeners();
      }
    } catch (e) {
      print('Error loading conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load conversation')),
      );
    }
  }

  Future<void> sendMessage(
      String message, {
        bool isAdmin = false,
        bool isSystem = false,
      }) async {
    if (message.trim().isEmpty || _currentConversation == null) return;

    if (_currentConversation!.status == 'ended') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This conversation has ended')),
      );
      return;
    }

    final userId = Provider.of<AuthProvider>(context, listen: false).userId;
    final senderName = isAdmin ? 'Customer Service' : 'You';

    try {
      // Create MessageModel
      final messageModel = MessageModel(
        id: '', // Will be set by Firestore
        message: message,
        senderId: isAdmin ? 'admin' : userId!,
        senderName: senderName,
        timestamp: null, // Will be set by server
        isAdmin: isAdmin,
        isSystem: isSystem,
      );

      // Add message using the model
      await _firestore
          .collection('conversations')
          .doc(_currentConversation!.id)
          .collection('messages')
          .add(messageModel.toMap());

      // Update last message timestamp
      await _firestore.collection('conversations').doc(_currentConversation!.id).update({
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  Stream<QuerySnapshot>? getMessagesStream() {
    if (_currentConversation == null) return null;

    return _firestore
        .collection('conversations')
        .doc(_currentConversation!.id)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Updated to return Stream of ConversationModel list
  Stream<List<ConversationModel>> getConversationsModelStream() {
    final userId = Provider.of<AuthProvider>(context, listen: false).userId;
    return _firestore
        .collection('conversations')
        .where('userId', isEqualTo: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ConversationModel.fromFirestore(doc))
        .toList());
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