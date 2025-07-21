// create_conversation_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../model/order_model.dart';
import 'admin_chat_controller.dart';

class CreateConversationDialog extends StatefulWidget {
  final AdminChatController controller;

  const CreateConversationDialog({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<CreateConversationDialog> createState() => _CreateConversationDialogState();
}

class _CreateConversationDialogState extends State<CreateConversationDialog> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedUserId;
  String? _selectedUserName;
  String? _selectedOrderId;
  List<Map<String, dynamic>> _searchResults = [];
  List<OrdersModel> _userOrders = [];
  bool _isSearching = false;
  bool _isLoadingOrders = false;
  bool _isGeneralInquiry = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = await widget.controller.searchUsers(query);

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _selectUser(Map<String, dynamic> user) async {
    setState(() {
      _selectedUserId = user['id'];
      _selectedUserName = user['name'];
      _searchResults = [];
      _searchController.text = user['email'];
      _isLoadingOrders = true;
    });

    // Load user's orders
    final orders = await widget.controller.getUserOrders(user['id']);

    setState(() {
      _userOrders = orders;
      _isLoadingOrders = false;
      // Auto-select general inquiry if no orders
      if (orders.isEmpty) {
        _isGeneralInquiry = true;
        _selectedOrderId = 'general';
      }
    });
  }

  void _createConversation() {
    if (_selectedUserId == null || _selectedOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user and order')),
      );
      return;
    }

    widget.controller.createNewConversation(
      userId: _selectedUserId!,
      orderId: _selectedOrderId!,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.purple[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.add_comment,
                    color: Colors.purple[700],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Start New Conversation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // User search
            Text(
              'Search Customer',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter customer email',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _isSearching
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : null,
              ),
              onChanged: (value) => _searchUsers(),
            ),

            // Search results
            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _searchResults.map((user) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple[100],
                        child: Text(
                          user['name'][0].toUpperCase(),
                          style: TextStyle(color: Colors.purple[700]),
                        ),
                      ),
                      title: Text(user['fullName'] ?? 'Unknown'),
                      subtitle: Text(user['email']),
                      onTap: () => _selectUser(user),
                    );
                  }).toList(),
                ),
              ),

            // Selected user info
            if (_selectedUserId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.purple[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Selected: $_selectedUserName',
                      style: TextStyle(
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Order selection
            if (_selectedUserId != null) ...[
              const SizedBox(height: 16),
              Text(
                'Select Order or Inquiry Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),

              // General Inquiry option
              RadioListTile<String>(
                value: 'general',
                groupValue: _selectedOrderId,
                onChanged: (value) {
                  setState(() {
                    _selectedOrderId = value;
                    _isGeneralInquiry = true;
                  });
                },
                title: const Text('General Inquiry'),
                subtitle: const Text('Start a general conversation'),
                activeColor: Colors.purple,
              ),

              if (_isLoadingOrders)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_userOrders.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Or select a specific order:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _userOrders.length,
                    itemBuilder: (context, index) {
                      final order = _userOrders[index];
                      return RadioListTile<String>(
                        value: order.id,
                        groupValue: _selectedOrderId,
                        onChanged: (value) {
                          setState(() {
                            _selectedOrderId = value;
                            _isGeneralInquiry = false;
                          });
                        },
                        title: Text('Order #${order.shortOrderId}'),
                        subtitle: Text(
                          'RM ${order.totalAmount.toStringAsFixed(2)} - ${order.orderStatus}',
                        ),
                        activeColor: Colors.purple,
                      );
                    },
                  ),
                ),
              ],
            ],

            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedUserId != null && _selectedOrderId != null
                      ? _createConversation
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Start Conversation'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}