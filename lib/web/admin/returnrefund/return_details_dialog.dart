// File: return_details_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../view/widgets/return_status_utils.dart';

class ReturnDetailsDialog {
  static Future<void> show(
      BuildContext context, {
        required Map<String, dynamic> returnItem,
        required Future<void> Function(String userId, String returnId, String newStatus) onUpdateReturnStatus,
        required String Function(int timestamp) formatDate,
        required String Function(String status) formatStatus,
        required FirebaseFirestore firestore,
      }) async {
    String currentStatus = returnItem['status'] ?? 'pending';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                width: 700,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Return #${returnItem['returnId']}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Order: #${returnItem['orderId']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Status dropdown
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: currentStatus,
                                underline: const SizedBox(),
                                isDense: true,
                                items: ['pending', 'approved', 'refunded', 'rejected']
                                    .map((status) => DropdownMenuItem(
                                  value: status,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: ReturnStatusUtils.getReturnStatusColor(status),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Text(_formatReturnStatus(status)),
                                    ],
                                  ),
                                ))
                                    .toList(),
                                onChanged: (newStatus) async {
                                  if (newStatus != null) {
                                    setState(() => currentStatus = newStatus);
                                    await onUpdateReturnStatus(
                                      returnItem['userId'],
                                      returnItem['id'],
                                      newStatus,
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Return Info Row
                    _buildReturnInfoRow(returnItem, formatDate),
                    const SizedBox(height: 20),

                    // Return Details Section
                    Text(
                      'Return Details',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Return Reason Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Return Reason',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            returnItem['reason'] ?? 'No reason provided',
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          if (returnItem['description'] != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Additional Comments',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    returnItem['description'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Products Section (if available)
                    if (returnItem['products'] != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Returned Products',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildReturnProductsList(returnItem['products']),
                    ],

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Refund Amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Refund Amount:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'RM ${(returnItem['total'] ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (currentStatus == 'pending') ...[
                          TextButton(
                            onPressed: () async {
                              setState(() => currentStatus = 'rejected');
                              await onUpdateReturnStatus(
                                returnItem['userId'],
                                returnItem['id'],
                                'rejected',
                              );
                            },
                            child: const Text(
                              'Reject Return',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              setState(() => currentStatus = 'approved');
                              await onUpdateReturnStatus(
                                returnItem['userId'],
                                returnItem['id'],
                                'approved',
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Approve Return'),
                          ),
                        ],
                        if (currentStatus == 'approved')
                          ElevatedButton(
                            onPressed: () async {
                              final confirmed = await _showRefundConfirmationDialog(context);
                              if (confirmed) {
                                setState(() => currentStatus = 'refunded');
                                await onUpdateReturnStatus(
                                  returnItem['userId'],
                                  returnItem['id'],
                                  'refunded',
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Process Refund'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildReturnInfoRow(Map<String, dynamic> returnItem, String Function(int) formatDate) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoColumn(
            'Return Date',
            formatDate(returnItem['date'] ?? 0),
          ),
          _verticalDivider(),
          _buildInfoColumn(
            'Customer ID',
            returnItem['userId']?.toString() ?? 'Unknown',
          ),
          _verticalDivider(),
          _buildInfoColumn(
            'Return Type',
            returnItem['returnType'] ?? 'Standard',
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoColumn(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  static Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.grey[300],
    );
  }

  static Widget _buildReturnProductsList(List<dynamic> products) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] ?? 'Unknown Product',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quantity: ${product['quantity'] ?? 1}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'RM ${(product['price'] ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  static String _formatReturnStatus(String status) {
    return status[0].toUpperCase() + status.substring(1);
  }

  static Future<bool> _showRefundConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Refund'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to process this refund?'),
            const SizedBox(height: 16),
            Text(
              'This action will initiate the refund process and cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            child: const Text('Confirm Refund'),
          ),
        ],
      ),
    ) ??
        false;
  }
}