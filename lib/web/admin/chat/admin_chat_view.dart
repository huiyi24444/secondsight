// admin_chat_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../model/conversation_model.dart';
import '../../../view/widgets/build_message.dart';
import '../widget/topbar.dart';
import 'admin_chat_controller.dart';
import 'create_conversation_dialog.dart';
import 'order_details_in_chat.dart';

class AdminChatView extends StatefulWidget {
  const AdminChatView({Key? key}) : super(key: key);

  @override
  State<AdminChatView> createState() => _AdminChatViewState();
}

class _AdminChatViewState extends State<AdminChatView> {
  late AdminChatController _controller;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AdminChatController(context);
    _controller.addListener(_onControllerUpdate);
    _controller.loadConversations();
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use responsive layout for web
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: CustomTopBar(
          title: 'Admin',
          subtitle: 'Conversations',
        ),
      ),
      body: Row(
        children: [
          // Sidebar with conversations list
          Container(
            width: 350,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                // Admin Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.purple[700],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Admin Chat Panel',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search conversations...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onChanged: (value) {
                            _controller.filterConversations(value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Filter tabs
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildFilterTab('All', _controller.filterStatus == 'all'),
                      const SizedBox(width: 8),
                      _buildFilterTab('Active', _controller.filterStatus == 'active'),
                      const SizedBox(width: 8),
                      _buildFilterTab('Ended', _controller.filterStatus == 'ended'),
                    ],
                  ),
                ),
                // Conversations list
                Expanded(
                  child: _buildConversationsList(),
                ),
                // Create new conversation button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: () => _showCreateConversationDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('New Conversation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main chat area
          Expanded(
            child: _controller.selectedConversation == null
                ? _buildEmptyState()
                : _buildChatInterface(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, bool isActive) {
    return InkWell(
      onTap: () {
        _controller.setFilterStatus(label.toLowerCase());
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.purple[100] : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.purple[300]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.purple[700] : Colors.grey[600],
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsList() {
    return StreamBuilder<List<ConversationModel>>(
      stream: _controller.getFilteredConversationsStream(),
      builder: (context, snapshot) {

        if (snapshot.hasError) {
          print('[ERROR] Conversation stream error: ${snapshot.error}');
          return const Center(child: Text('Something went wrong.'));
        }

        if (!snapshot.hasData) {
          print('[DEBUG] No data yet from conversation stream.');
          return const Center(child: CircularProgressIndicator());
        }
        final conversations = snapshot.data!;
        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No conversations found',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            final isSelected = _controller.selectedConversation?.id == conversation.id;

            return FutureBuilder<Map<String, dynamic>>(
              future: _controller.getConversationDetails(conversation),
              builder: (context, detailsSnapshot) {
                final userName = detailsSnapshot.data?['userName'] ?? 'Loading...';
                final lastMessage = detailsSnapshot.data?['lastMessage'] ?? '';
                final unreadCount = detailsSnapshot.data?['unreadCount'] ?? 0;

                return InkWell(
                  onTap: () => _controller.selectConversation(conversation),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.purple[50] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.purple[300]! : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        // User avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.purple[100],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: Colors.purple[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Conversation details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      userName.isNotEmpty ? 'User #${userName.toUpperCase()}' : 'User #??????',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        unreadCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                conversation.orderId == 'general'
                                    ? 'General Inquiry'
                                    : 'Order #${conversation.shortOrderId}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple[600],
                                ),
                              ),
                              if (lastMessage.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  lastMessage,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: conversation.status == 'active'
                                          ? Colors.green[100]
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      conversation.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: conversation.status == 'active'
                                            ? Colors.green[700]
                                            : Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _controller.formatDate(
                                      conversation.lastMessageAt?.toDate() ?? DateTime.now(),
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'Select a conversation to start chatting',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose from the list on the left or create a new one',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInterface() {
    return Column(
      children: [
        // Chat header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _controller.getConversationDetails(_controller.selectedConversation!),
            builder: (context, snapshot) {
              final userName = snapshot.data?['userName'] ?? 'Loading...';
              final userEmail = snapshot.data?['userEmail'] ?? '';
              final fullName = snapshot.data?['fullName'] ?? 'Unknown Name';

              return Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (userEmail.isNotEmpty)
                          Text(
                            userEmail,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_controller.selectedConversation!.orderId != 'general')
                    Builder(
                      builder: (context) {
                        bool isHovered = false;

                        return StatefulBuilder(
                          builder: (context, setState) {
                            return MouseRegion(
                              onEnter: (_) => setState(() => isHovered = true),
                              onExit: (_) => setState(() => isHovered = false),
                              child: InkWell(
                                onTap: () {
                                  orderDetailsInChat(_controller.selectedConversation!.orderId);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[50],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Order #${_controller.selectedConversation!.shortOrderId}',
                                    style: TextStyle(
                                      color: Colors.purple[700],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      decoration: isHovered
                                          ? TextDecoration.underline
                                          : TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),



                  const SizedBox(width: 12),
                  if (_controller.selectedConversation!.status == 'active')
                    ElevatedButton.icon(
                      onPressed: () => _controller.endConversation(),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('End Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red[700],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.red[200]!),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        // Messages area
        Expanded(
          child: Container(
            color: Colors.grey[50],
            child: StreamBuilder<QuerySnapshot>(
              stream: _controller.getMessagesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                // Mark messages as read when viewing
                _controller.markMessagesAsRead();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isMe = message['isAdmin'] ?? false;
                    final isSystem = message['isSystem'] ?? false;

                    return buildMessage(
                      context,
                      message['message'] ?? '',
                      isMe: isMe && !isSystem,
                      isAdmin: isMe,
                      isSystem: isSystem,
                      timestamp: message['timestamp'],
                      senderName: message['senderName'],
                    );
                  },
                );
              },
            ),
          ),
        ),
        // Message input
        if (_controller.selectedConversation!.status == 'active')
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
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _messageController,
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
                        if (value.trim().isNotEmpty) {
                          _controller.sendMessage(value.trim());
                          _messageController.clear();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.purple[600],
                  borderRadius: BorderRadius.circular(25),
                  child: InkWell(
                    onTap: () {
                      final text = _messageController.text.trim();
                      if (text.isNotEmpty) {
                        _controller.sendMessage(text);
                        _messageController.clear();
                      }
                    },
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
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
      ],
    );
  }

  void _showCreateConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateConversationDialog(
        controller: _controller,
      ),
    );
  }
}