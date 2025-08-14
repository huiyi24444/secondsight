import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:secondsight/view/widgets/custom_back_button.dart';
import '../../services/auth_provider.dart';
import '../../model/conversation_model.dart'; // Import your model

class ConversationList extends StatelessWidget {
  final FirebaseFirestore firestore;
  final Function(String) onSelectConversation;
  final VoidCallback onStartNew;
  final bool showList;
  final BuildContext context;
  final String? conversationId;
  final String? conversationStatus;
  final String Function(DateTime) formatDate;

  const ConversationList({
    Key? key,
    required this.firestore,
    required this.onSelectConversation,
    required this.onStartNew,
    required this.context,
    required this.formatDate,
    required this.showList,
    this.conversationId,
    this.conversationStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context, listen: false).userId;


    return Column(
      children: [
        // Header (unchanged)
        Container(

          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Conversations',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.purple[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'View your chat history',
                style: TextStyle(fontSize: 14, color: Colors.purple[700]),
              ),
            ],
          ),
        ),

        // Conversations List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('conversations')
                .where('userId', isEqualTo: userId)
                .orderBy('lastMessageAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading conversations'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final conversations = snapshot.data!.docs
                  .map((doc) => ConversationModel.fromFirestore(doc))
                  .toList();

              if (conversations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 20),
                      Text(
                        'No conversations yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: onStartNew,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text('Start New Conversation'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];

                  return GestureDetector(
                    onTap: () => onSelectConversation(conversation.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: conversation.status == 'active'
                                  ? Colors.purple[100]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Icon(
                              Icons.chat,
                              color: conversation.status == 'active'
                                  ? Colors.purple
                                  : Colors.grey[400],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order #${conversation.shortOrderId}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (conversation.lastMessageAt != null)
                                      Text(
                                        formatDate(conversation.lastMessageAt!.toDate()),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: conversation.status == 'active'
                                            ? Colors.green[100]
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        conversation.status == 'active'
                                            ? 'Active'
                                            : 'Ended',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: conversation.status == 'active'
                                              ? Colors.green[700]
                                              : Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),


      ],
    );
  }
}
