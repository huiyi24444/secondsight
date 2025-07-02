// lib/view/chat/chat_interface_widget.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/auth_provider.dart';

class ChatInterfaceWidget extends StatelessWidget {
  final dynamic controller;
  final ScrollController scrollController;
  final TextEditingController messageController;

  const ChatInterfaceWidget({
    Key? key,
    required this.controller,
    required this.scrollController,
    required this.messageController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (controller.selectedOrder != null &&
            controller.selectedOrder!.id != 'General Inquiry')
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              border: Border(bottom: BorderSide(color: Colors.purple[100]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.purple[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chatting about Order #${controller.selectedOrder!.id}',
                    style: TextStyle(
                      color: Colors.purple[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (controller.conversationStatus == 'ended')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Ended',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: controller.getMessagesStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snapshot.data!.docs;
              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message =
                  messages[index].data() as Map<String, dynamic>;
                  final userId =
                      Provider.of<AuthProvider>(context, listen: false).userId;
                  final isMe = message['senderId'] == userId;
                  final isAdmin = message['isAdmin'] ?? false;
                  final isSystem = message['isSystem'] ?? false;

                  return _buildMessage(
                    context,
                    message['message'] ?? '',
                    isMe: isMe && !isSystem,
                    isAdmin: isAdmin,
                    isSystem: isSystem,
                    timestamp: message['timestamp'],
                  );
                },
              );
            },
          ),
        ),
        if (controller.conversationStatus != 'ended')
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: messageController,
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (value) {
                          if (value.trim().isEmpty) return;
                          controller.sendMessage(value.trim());
                          messageController.clear();
                        },

                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      final text = messageController.text.trim();
                      if (text.isEmpty) return;
                      controller.sendMessage(text);
                      messageController.clear();
                    },

                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple[400]!, Colors.purple[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Center(
                child: Text(
                  'This conversation has ended',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessage(
      BuildContext context,
      String message, {
        required bool isMe,
        required bool isAdmin,
        required bool isSystem,
        Timestamp? timestamp,
      }) {
    final time = timestamp != null
        ? DateFormat('HH:mm').format(timestamp.toDate())
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && !isSystem) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.purple,
              child: Icon(
                Icons.support_agent,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.purple
                    : isSystem
                    ? Colors.orange[100]
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && !isSystem)
                    Text(
                      isAdmin ? 'Customer Service' : 'System',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple[700],
                      ),
                    ),
                  if (!isMe && !isSystem) const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : isSystem
                          ? Colors.orange[900]
                          : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe
                            ? Colors.white70
                            : isSystem
                            ? Colors.orange[700]
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: Icon(Icons.person, color: Colors.grey[600], size: 20),
            ),
          ],
        ],
      ),
    );
  }
}
