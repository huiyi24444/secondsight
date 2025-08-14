
//chat_order_selection.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:secondsight/view/widgets/order_status_utils.dart';

import '../../controller/chat/chat_support_controller.dart';
import '../../model/order_model.dart';
import '../../model/order_product_model.dart';
import '../../services/auth_provider.dart';
import '../widgets/chat_history_widget.dart';
import '../../model/conversation_model.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/long_button.dart';
import 'chat_history_view.dart';
import 'chat_interface_view.dart';
import 'end_chat_dialog.dart';

class ChatSupportView extends StatefulWidget {
  const ChatSupportView({Key? key}) : super(key: key);

  @override
  State<ChatSupportView> createState() => _ChatSupportViewState();
}

class _ChatSupportViewState extends State<ChatSupportView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatSupportController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChatSupportController(context);
    _controller.addListener(_onControllerUpdate);
    _controller.showOrderSelectionView();
    _controller.setLoadingComplete();
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
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: CustomBackButton(
          onPressed: () {
            if (_controller.showConversationList || _controller.showOrderSelection) {
              Navigator.pop(context); // Go back to previous screen
            } else {
              setState(() {
                _controller.showOrderSelectionView(); // Go back to internal state
              });
            }
          },
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
                  'Typically replies within minutes',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_controller.showConversationList || _controller.showOrderSelection)
            IconButton(
              icon: const Icon(Icons.history, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConversationListPage(
                      firestore: FirebaseFirestore.instance,
                      onSelectConversation: (id) {
                        Navigator.pop(context);
                        _controller.loadConversation(id);
                      },
                      onStartNew: () {
                        Navigator.pop(context);
                        _controller.showOrderSelectionView();
                      },
                      formatDate: _controller.formatDate,
                      conversationId: _controller.conversationId,
                      conversationStatus: _controller.conversationStatus,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: _controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _controller.showConversationList
          ? ConversationList(
        firestore: FirebaseFirestore.instance,
        context: context,
        showList: _controller.showConversationList,
        conversationId: _controller.conversationId,
        conversationStatus: _controller.conversationStatus,
        onSelectConversation: _controller.loadConversation,
        onStartNew: () => _controller.showOrderSelectionView(),
        formatDate: _controller.formatDate,
      )
          : _controller.showOrderSelection
          ? _buildOrderSelection()
          : ChatInterfaceWidget(
        controller: _controller,
        scrollController: _scrollController,
        messageController: _messageController,
      ),
    );
  }

  Widget _buildOrderSelection() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header
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
                  'Hello! Welcome to Customer Care Service.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.purple[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please select your order to help us serve you better:',
                  style: TextStyle(fontSize: 14, color: Colors.purple[700]),
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _controller.getOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading orders'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data!.docs
                    .map((doc) => OrdersModel.fromJson(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
                    .toList();

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined,
                            size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 20),
                        Text(
                          'No orders found',
                          style:
                          TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            _controller.setSelectedOrder(OrdersModel(
                              id: 'General Inquiry',
                              orderDate: DateTime.now(),
                              orderStatus: 'general',
                              totalAmount: 0.0,
                              eligibilityForReturn: false,
                              totalProduct: 0,
                              paymentCard: '',
                            ));
                            _controller.startConversation();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text('Start General Inquiry'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length + 1,
                  itemBuilder: (context, index) {
                    if (index == orders.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () {
                            _controller.setSelectedOrder(OrdersModel(
                              id: 'general',
                              orderDate: DateTime.now(),
                              orderStatus: 'general',
                              totalAmount: 0.0,
                              eligibilityForReturn: false,
                              totalProduct: 0,
                              paymentCard: '',
                            ));
                            _controller.startConversation();
                          },
                          child: const Text(
                            'General Inquiry',
                            style: TextStyle(color: Colors.purple),
                          ),
                        ),
                      );
                    }

                    final order = orders[index];
                    final isSelected = _controller.selectedOrder?.id == order.id;

                    return GestureDetector(
                      onTap: () => _controller.setSelectedOrder(order),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.purple[50] : Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? Colors.purple
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
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
                            // Placeholder image box
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 28,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Order Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #${order.shortOrderId}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'RM ${order.totalAmount.toStringAsFixed(
                                        2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: OrderStatusUtils.getStatusColor(order.orderStatus),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      OrderStatusUtils.formatStatus(order.orderStatus),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Selection indicator
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.purple
                                      : Colors.grey[400]!,
                                  width: 2,
                                ),
                                color: isSelected
                                    ? Colors.purple
                                    : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                                  : null,
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

          // Next Button
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
              child: LongButton(
                label: 'Next',
                onPressed: _controller.selectedOrder != null
                    ? _controller.startConversation
                    : () {}, // or disable button logic if needed
              ),
            ),
          ),

        ],
      ),
    );
  }
}



