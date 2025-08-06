// cancellation_details_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../model/cancel_model.dart';

// Import this widget in your order_details_view.dart file:
// import 'cancellation_details_widget.dart';

class CancellationDetailsWidget extends StatelessWidget {
  final CancellationModel cancellation;

  const CancellationDetailsWidget({
    super.key,
    required this.cancellation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with cancellation icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.cancel_outlined,
                  color: Colors.red.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Order Cancelled',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Cancellation details
          _buildDetailRow(
            icon: Icons.event_outlined,
            label: 'Cancelled On',
            value: _formatCancellationDate(cancellation.cancelDate),
            iconColor: Colors.red.shade600,
          ),

          const SizedBox(height: 8),

          _buildDetailRow(
            icon: Icons.info_outline,
            label: 'Reason',
            value: cancellation.cancelReason,
            iconColor: Colors.orange.shade600,
          ),

          if (cancellation.cancelNote != null && cancellation.cancelNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.note_outlined,
              label: 'Additional Notes',
              value: cancellation.cancelNote!,
              iconColor: Colors.blue.shade600,
              isMultiline: true,
            ),
          ],

          const SizedBox(height: 8),

          _buildDetailRow(
            icon: Icons.person_outline,
            label: 'Cancelled By',
            value: cancellation.cancelledBy,
            iconColor: Colors.grey.shade600,
          ),

          // Information note
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.blue.shade200,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade600,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Your payment will be refunded within 3-5 business days.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    bool isMultiline = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                  maxLines: isMultiline ? null : 2,
                  overflow: isMultiline ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCancellationDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('HH:mm').format(date)}';
    } else {
      return '${DateFormat('EEEE').format(date)}, ${DateFormat('MMM d, yyyy').format(date)} at ${DateFormat('h:mm a').format(date)}';
    }
  }
}