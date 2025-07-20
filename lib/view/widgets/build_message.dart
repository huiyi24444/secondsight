import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Widget buildMessage(
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