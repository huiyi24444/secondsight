import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../model/order_model.dart';
import '../../model/conversation_model.dart';
import '../../services/auth_provider.dart';
import '../../view/chat/active_conversation_dialog.dart';
import '../order/notif_controller.dart';

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
      // Set flags immediately to prevent showing order selection
      _showConversationList = false;
      _showOrderSelection = false;
      _currentConversation = ConversationModel(
        id: conversationId,
        userId: '', // Will be updated below
        orderId: '', // Will be updated below
        status: 'active', // Will be updated below
        createdAt: Timestamp.now(), // Will be updated below
        lastMessageAt: Timestamp.now(), // Will be updated below
      );
      notifyListeners(); // Immediate UI update

      // Load conversation data from Firestore
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (conversationDoc.exists) {
        // Update with real conversation data
        _currentConversation = ConversationModel.fromFirestore(conversationDoc);

        // Load the associated order if it exists and is not a general inquiry
        if (_currentConversation!.orderId != 'general' && _currentConversation!.orderId.isNotEmpty) {
          try {
            final orderDoc = await _firestore
                .collection('users')
                .doc(_currentConversation!.userId)
                .collection('order')
                .doc(_currentConversation!.orderId)
                .get();

            if (orderDoc.exists) {
              _selectedOrder = OrdersModel.fromJson(
                orderDoc.data() as Map<String, dynamic>,
                orderDoc.id,
              );
            }
          } catch (e) {
            print('Error loading order: $e');
            // If order loading fails, create a placeholder
            _selectedOrder = OrdersModel(
              id: _currentConversation!.orderId,
              orderDate: DateTime.now(),
              orderStatus: 'unknown',
              totalAmount: 0.0,
              eligibilityForReturn: false,
              totalProduct: 0,
              paymentCard: '',
            );
          }
        } else {
          // It's a general inquiry
          _selectedOrder = OrdersModel(
            id: 'General Inquiry',
            orderDate: DateTime.now(),
            orderStatus: 'general',
            totalAmount: 0.0,
            eligibilityForReturn: false,
            totalProduct: 0,
            paymentCard: '',
          );
        }

        notifyListeners();
      } else {
        // Conversation doesn't exist, go back to order selection
        showOrderSelectionView();
      }
    } catch (e) {
      print('Error loading conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load conversation')),
      );
      // On error, go back to order selection
      showOrderSelectionView();
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

    String senderName;
    if (isAdmin) {
      senderName = 'Customer Service';
    } else if (isSystem) {
      senderName = 'System';
    } else {
      senderName = 'Customer'; // Or fetch from user profile
    }

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

// Extension methods for ChatSupportController
// Add these methods to your existing ChatSupportController class:

  /// Initialize controller for notification navigation
  Future<void> initializeFromNotification({
    required String conversationId,
    required String orderId,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Load the conversation
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (conversationDoc.exists) {
        _currentConversation = ConversationModel.fromFirestore(conversationDoc);

        // Load the associated order if it's not a general inquiry
        if (orderId != 'general') {
          final orderDoc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('order')
              .doc(orderId)
              .get();

          if (orderDoc.exists) {
            _selectedOrder = OrdersModel.fromJson(
                orderDoc.data() as Map<String, dynamic>,
                orderDoc.id
            );
          }
        } else {
          // It's a general inquiry
          _selectedOrder = OrdersModel(
            id: 'General Inquiry',
            orderDate: DateTime.now(),
            orderStatus: '',
            totalAmount: 0,
            eligibilityForReturn: false, paymentCard: '', totalProduct: 0,
          );
        }

        // Set flags to show the chat interface
        _showOrderSelection = false;
        _showConversationList = false;
        _isLoading = false;

        notifyListeners();
      }
    } catch (e) {
      print('Error initializing from notification: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Override sendMessage to create notifications for admin messages
  /// Add this to your ChatSupportController to replace the existing sendMessage method
  Future<void> sendMessageWithNotification(
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

    String senderName;
    String senderId;
    if (isAdmin) {
      senderName = 'Customer Service';
      senderId = 'admin';
    } else if (isSystem) {
      senderName = 'System';
      senderId = 'system';
    } else {
      senderName = 'Customer'; // Or fetch from user profile
      senderId = userId!;
    }

    try {
      // Create MessageModel
      final messageModel = MessageModel(
        id: '', // Will be set by Firestore
        message: message,
        senderId: senderId,
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

      // Create notification if message is from admin and not a system message
      if (isAdmin && !isSystem) {
        await NotificationController.createChatNotification(
          userId: _currentConversation!.userId,
          conversationId: _currentConversation!.id,
          orderId: _currentConversation!.orderId,
          senderName: senderName,
          lastMessage: message,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }
}