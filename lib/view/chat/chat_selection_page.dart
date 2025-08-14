import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_back_button.dart';
import 'chat_order_selection.dart';
import 'chat_history_view.dart';
import '../../controller/chat/chat_support_controller.dart';
import '../../services/auth_provider.dart';

class ChatSelectionPage extends StatelessWidget {
  const ChatSelectionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: CustomBackButton(
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[400]!, Colors.purple[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.headset_mic,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Customer Support',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'How can we help you today?',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),

            // Start New Conversation Card
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatOrderSelection(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.purple[100],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        Icons.add_comment_outlined,
                        color: Colors.purple[600],
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Start New Conversation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get help with a new issue or question',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // View Conversation History Card with Badge
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConversationListPage(
                      firestore: FirebaseFirestore.instance,
                      onSelectConversation: (id) {
                        Navigator.pop(context); // Pop the conversation list
                        Navigator.pop(context); // Pop the chat selection page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatOrderSelection(
                              conversationIdToLoad: id,
                            ),
                          ),
                        );
                      },
                      onStartNew: () {
                        Navigator.pop(context); // Pop the conversation list
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChatOrderSelection(),
                          ),
                        );
                      },
                      formatDate: (DateTime date) {
                        final now = DateTime.now();
                        final difference = now.difference(date);
                        if (difference.inDays == 0) return 'Today';
                        if (difference.inDays == 1) return 'Yesterday';
                        return '${difference.inDays}d ago';
                      },
                    ),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // History Icon with Badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Icon(
                            Icons.history,
                            color: Colors.blue[600],
                            size: 30,
                          ),
                        ),
                        // Unread Messages Badge
                        StreamBuilder<int>(
                          stream: _getUnreadMessagesCount(context),
                          builder: (context, snapshot) {
                            final unreadCount = snapshot.data ?? 0;

                            if (unreadCount == 0) return const SizedBox.shrink();

                            return Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'View Conversation History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Continue previous conversations',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  // Helper method to get unread messages count
  Stream<int> _getUnreadMessagesCount(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context, listen: false).userId;

    return FirebaseFirestore.instance
        .collectionGroup('messages')
        .where('isAdmin', isEqualTo: true)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .asyncMap((snapshot) async {
      int unreadCount = 0;

      for (var messageDoc in snapshot.docs) {
        // Get the conversation ID from the message document path
        final conversationId = messageDoc.reference.parent.parent!.id;

        // Check if this conversation belongs to the current user
        final conversationDoc = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .get();

        if (conversationDoc.exists &&
            conversationDoc.data()?['userId'] == userId) {
          unreadCount++;
        }
      }

      return unreadCount;
    });
  }
}