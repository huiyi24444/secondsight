import 'package:flutter/material.dart';

enum ReturnStatus { pending, approved, processing, completed }


class ReturnStatusInfo {
  final String title;
  final String subtitle;
  final String description;
  final String actionText;
  final IconData icon;
  final MaterialColor color;

  const ReturnStatusInfo({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.actionText,
    required this.icon,
    required this.color,
  });
}

class ReturnStatusCard extends StatelessWidget {
  final ReturnStatus status;

  const ReturnStatusCard({
    Key? key,
    required this.status,
  }) : super(key: key);

  ReturnStatusInfo _getStatusInfo() {
    switch (status) {
      case ReturnStatus.pending: // ✅ Add this
        return const ReturnStatusInfo(
          title: '',
          subtitle: '',
          description: '',
          actionText: '',
          icon: Icons.hourglass_empty,
          color: Colors.grey,
        );
      case ReturnStatus.approved:
        return const ReturnStatusInfo(
          title: 'Collection Scheduled',
          subtitle: 'We will collect your item for return processing',
          description: 'Our courier will arrive at your delivery address within 7 working days to collect the item.',
          actionText: 'Please keep the item ready for collection',
          icon: Icons.local_shipping_outlined,
          color: Colors.green,
        );
      case ReturnStatus.processing:
        return const ReturnStatusInfo(
          title: 'Item Collected',
          subtitle: 'Your item has been successfully collected',
          description: 'Your item is currently being inspected by our team. We will notify you once the inspection is complete.',
          actionText: 'Inspection in progress - please wait',
          icon: Icons.inventory_outlined,
          color: Colors.orange,
        );
      case ReturnStatus.completed:
        return const ReturnStatusInfo(
          title: 'Return Approved',
          subtitle: 'Your item has been approved for refund',
          description: 'The refund has been processed and will be credited to your original payment method.',
          actionText: 'Check refund details below',
          icon: Icons.check_circle_outline,
          color: Colors.blue,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
        border: Border.all(color: statusInfo.color.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusInfo.color.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  statusInfo.icon,
                  color: statusInfo.color.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusInfo.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: statusInfo.color.shade700,
                      ),
                    ),
                    Text(
                      statusInfo.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusInfo.color.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusInfo.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusInfo.color.shade200),
                  ),
                  child: Text(
                    statusInfo.actionText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusInfo.color.shade600,
                      fontWeight: FontWeight.w500,
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
}