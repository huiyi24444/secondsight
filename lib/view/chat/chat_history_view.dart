// views/chat/conversation_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/view/widgets/custom_back_button.dart';
import '../../model/conversation_model.dart';
import '../../services/auth_provider.dart';
import '../widgets/chat_history_widget.dart';
class ConversationListPage extends StatelessWidget {
  final FirebaseFirestore firestore;
  final String? conversationId;
  final String? conversationStatus;
  final Function(String) onSelectConversation;
  final VoidCallback onStartNew;
  final String Function(DateTime) formatDate;

  const ConversationListPage({
    Key? key,
    required this.firestore,
    required this.onSelectConversation,
    required this.onStartNew,
    required this.formatDate,
    this.conversationId,
    this.conversationStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: CustomBackButton(),
      ),
      body: ConversationList(
        firestore: firestore,
        onSelectConversation: onSelectConversation,
        onStartNew: onStartNew,
        context: context,
        formatDate: formatDate,
        showList: true,
        conversationId: conversationId,
        conversationStatus: conversationStatus,
      ),
    );
  }
}