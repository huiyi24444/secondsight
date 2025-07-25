// File: return_details_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../view/widgets/return_status_utils.dart';

class ReturnDetailsDialog {
  static Future<void> show(
      BuildContext context, {
        required Map<String, dynamic> returnItem,
        required Future<void> Function(String returnId, String newStatus) onUpdateReturnStatus,
        required String Function(int timestamp) formatDate,
        required String Function(String status) formatStatus,
        required FirebaseFirestore firestore,
        required Future<DocumentSnapshot> Function(String userId, String orderID, String orderProductID) getOrderProductDoc,
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
                              'Order: #${returnItem['shortOrderId']}', // Updated field name
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
                                items: ['submitted', 'approved', 'completed', 'rejected'] // Updated status values
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
                          // Show return comment from the return request
                          FutureBuilder<Map<String, dynamic>?>(
                            future: _getReturnRequestDetails(firestore, returnItem['id']),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data?['returnComment'] != null) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                            snapshot.data!['returnComment'],
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),

                    // Product Details Section using order product data
                    const SizedBox(height: 20),
                    Text(
                      'Product Details',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _getOrderProductDetails(getOrderProductDoc, returnItem),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return _buildProductCard(snapshot.data!);
                        }
                        return const CircularProgressIndicator();
                      },
                    ),

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
                          'RM ${(returnItem['returnPrice'] ?? 0).toStringAsFixed(2)}', // Updated to use returnPrice
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
                        if (currentStatus == 'submitted') ...[
                          TextButton(
                            onPressed: () async {
                              setState(() => currentStatus = 'rejected');
                              await onUpdateReturnStatus(
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
                                setState(() => currentStatus = 'completed');
                                await onUpdateReturnStatus(
                                  returnItem['id'],
                                  'completed',
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

  // Helper method to get return request details
  static Future<Map<String, dynamic>?> _getReturnRequestDetails(FirebaseFirestore firestore, String returnId) async {
    try {
      final doc = await firestore.collection('returnRequests').doc(returnId).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print('Error fetching return request details: $e');
    }
    return null;
  }

  // Helper method to get order product details
  static Future<Map<String, dynamic>?> _getOrderProductDetails(
      Future<DocumentSnapshot> Function(String, String, String) getOrderProductDoc,
      Map<String, dynamic> returnItem) async {
    try {
      // Extract data from returnItem (this comes from the mapped data in loadReturns)
      // You'll need to get the actual userID from the return request document
      final firestore = FirebaseFirestore.instance;
      final returnDoc = await firestore.collection('returnRequests').doc(returnItem['id']).get();

      if (returnDoc.exists) {
        final returnData = returnDoc.data() as Map<String, dynamic>;
        final orderProductDoc = await getOrderProductDoc(
            returnData['userID'],
            returnData['orderID'],
            returnData['orderProductID']
        );

        if (orderProductDoc.exists) {
          return orderProductDoc.data() as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      print('Error fetching order product details: $e');
    }
    return null;
  }

  static Widget _buildProductCard(Map<String, dynamic> productData) {
    return Container(
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
                  'Product Quantity: ${productData['productQuantity'] ?? 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unit Price: RM ${(productData['price'] ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Total: RM ${(productData['totalPrice'] ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
            'Customer Email',
            returnItem['userEmail'] ?? 'Unknown', // Updated to use userEmail
          ),
          _verticalDivider(),
          _buildInfoColumn(
            'Order Product ID',
            returnItem['orderProductId'] ?? 'Unknown', // Show order product ID
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