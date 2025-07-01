// File: return_details_dialog.dart
import 'package:flutter/material.dart';

Widget buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

Future<void> showReturnDetailsDialog({
  required BuildContext context,
  required Map<String, dynamic> returnItem,
  required Future<void> Function(String userId, String returnId, String newStatus) onUpdateReturnStatus,
  required String Function(int timestamp) formatDate,
  required String Function(String status) formatStatus,
}) async {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Return Details'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildDetailRow('Return ID', '#${returnItem['returnId']}'),
            buildDetailRow('Order ID', '#${returnItem['orderId']}'),
            buildDetailRow('User ID', returnItem['userId']?.toString() ?? 'Unknown'),
            buildDetailRow('Date', formatDate(returnItem['date'])),
            buildDetailRow('Status', formatStatus(returnItem['status'])),
            buildDetailRow('Reason', returnItem['reason']),
            buildDetailRow('Refund Amount', 'RM ${returnItem['total'].toStringAsFixed(2)}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (returnItem['status'] == 'pending')
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onUpdateReturnStatus(returnItem['userId'], returnItem['id'], 'approved');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve Return'),
          ),
        if (returnItem['status'] == 'approved')
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onUpdateReturnStatus(returnItem['userId'], returnItem['id'], 'refunded');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C3AED)),
            child: const Text('Process Refund'),
          ),
      ],
    ),
  );
}
