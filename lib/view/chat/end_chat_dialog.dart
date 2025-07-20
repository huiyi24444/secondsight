
import 'package:flutter/material.dart';

class EndConversationDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final String title;
  final String message;

  const EndConversationDialog({
    Key? key,
    required this.onConfirm,
    this.title = 'End Conversation',
    this.message = 'Are you sure you want to end this conversation? You won\'t be able to send new messages.',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: const Text('End'),
        ),
      ],
    );
  }

  // Static method to show the dialog easily
  static Future<void> show({
    required BuildContext context,
    required VoidCallback onConfirm,
    String? title,
    String? message,
  }) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return EndConversationDialog(
          onConfirm: onConfirm,
          title: title ?? 'End Conversation',
          message: message ?? 'Are you sure you want to end this conversation? You won\'t be able to send new messages.',
        );
      },
    );
  }
}