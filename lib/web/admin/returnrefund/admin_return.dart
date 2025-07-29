import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/view/widgets/return_status_utils.dart';

import '../../../model/return_request_model.dart';
import '../../../web/admin/returnrefund/return_details_dialog.dart';
import '../widget/topbar.dart';
import 'admin_return_controller.dart';
import 'admin_return_details.dart';

class ReturnManagementPage extends StatelessWidget {
  const ReturnManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReturnManagementController()..loadReturns(),
      child: const ReturnManagementView(),
    );
  }
}

class ReturnManagementView extends StatelessWidget {
  const ReturnManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReturnManagementController>();

    final totalPages = (controller.filteredReturns.length / controller.itemsPerPage).ceil();
    final startIndex = (controller.currentPage - 1) * controller.itemsPerPage;
    final endIndex = (startIndex + controller.itemsPerPage).clamp(0, controller.filteredReturns.length);
    final currentReturns = controller.filteredReturns.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const CustomTopBar(
                  title: 'Return Requests',
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Search & Add
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: controller.searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search return...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onChanged: (_) => controller.filterReturns(),
                                ),
                              ),
                              const SizedBox(width: 20),
                              ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.add),
                                label: const Text('Add Return'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tabs
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              _buildFilterTab(context, 'All'),
                              const SizedBox(width: 20),
                              _buildFilterTab(context, 'Submitted'),  // Updated from 'Pending'
                              const SizedBox(width: 20),
                              _buildFilterTab(context, 'Approved'),
                              const SizedBox(width: 20),
                              _buildFilterTab(context, 'Completed'),  // Updated from 'Refunded'
                              const SizedBox(width: 20),
                              _buildFilterTab(context, 'Rejected'),
                              const SizedBox(width: 20),
                              _buildFilterTab(context, 'Cancelled'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Table
                        Expanded(
                          child: controller.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: SizedBox(width: 30, child: Checkbox(value: false, onChanged: null))),
                                DataColumn(label: Text('Return ID')),
                                DataColumn(label: Text('Order ID')),
                                DataColumn(label: Text('Order Product ID')),
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Customer')),
                                DataColumn(label: Text('Price')),
                                DataColumn(label: Text('Payment')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Action')),
                              ],
                              rows: currentReturns.map((item) {
                                return DataRow(cells: [
                                  const DataCell(Checkbox(value: false, onChanged: null)),
                                  DataCell(Text('#${item['returnId']}')),
                                  DataCell(Text('#${item['shortOrderId']}')),
                                  DataCell(Text(item['orderProductId'])),
                                  DataCell(Text(controller.formatDate(item['date']))),
                                  DataCell(Text(item['userEmail'] ?? 'Unknown')),
                                  DataCell(Text('RM ${item['returnPrice'].toStringAsFixed(2)}')),
                                  const DataCell(Text('Mastercard')),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: ReturnStatusUtils.getReturnStatusColor(item['status']).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        controller.formatStatus(item['status']),
                                        style: TextStyle(
                                          color: ReturnStatusUtils.getReturnStatusColor(item['status']),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) async {
                                        if (value == 'view') {
                                          // Convert the item map to ReturnRequestModel before navigation
                                          // Note: Adjust field names based on your actual Map structure
                                          final returnRequest = ReturnRequestModel(
                                            id: item['id'] ?? '',
                                            orderProductID: item['orderProductId'] ?? item['orderProductID'] ?? '',
                                            orderID: item['orderId'] ?? item['orderID'] ?? '',
                                            userID: item['userEmail'] ?? item['userID'] ?? '',
                                            returnDate: item['date'] is Timestamp
                                                ? item['date'] as Timestamp
                                                : item['returnDate'] is Timestamp
                                                ? item['returnDate'] as Timestamp
                                                : Timestamp.now(),
                                            returnImages: item['images'] != null
                                                ? List<String>.from(item['images'])
                                                : item['returnImages'] != null
                                                ? List<String>.from(item['returnImages'])
                                                : [],
                                            returnReason: item['reason'] ?? item['returnReason'] ?? '',
                                            returnStatus: item['status'] ?? item['returnStatus'] ?? 'pending',
                                            returnComment: item['comment'] ?? item['returnComment'] ?? '',
                                            rejectReason: item['rejectReason'],
                                            returnPrice: item['returnPrice'] != null
                                                ? (item['returnPrice'] as num).toDouble()
                                                : 0.0,
                                            returnQuantity: item['quantity'] ?? item['returnQuantity'] ?? 1,
                                            productName: item['productName'] ?? 'Unknown Product',
                                            productImageUrl: item['productImage'] ?? item['productImageUrl'] ?? '',
                                            pendingDate: item['pendingDate'] as Timestamp?,
                                            approvedDate: item['approvedDate'] as Timestamp?,
                                            rejectedDate: item['rejectedDate'] as Timestamp?,
                                            completedDate: item['completedDate'] as Timestamp?,
                                            pendinginspectionDate: item['pendinginspectionDate'] as Timestamp?,
                                            completedinsepectionDate: item['completedinsepectionDate'] as Timestamp?,
                                            cancelledDate: item['cancelledDate'] as Timestamp?,
                                          );

                                          // Navigate to the ReturnDetailsPage with ReturnRequestModel
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ReturnDetailsPage(
                                                returnRequest: returnRequest,
                                                onUpdateReturnStatus: (returnId, newStatus) async {
                                                  try {
                                                    await controller.updateReturnStatus(
                                                        context,
                                                        item['userEmail'] ?? item['userID'] ?? '',
                                                        returnId,
                                                        newStatus
                                                    );
                                                    return true;
                                                  } catch (e) {
                                                    return false;
                                                  }
                                                },
                                                formatDate: (timestamp) {
                                                  // Convert Timestamp to milliseconds for your controller
                                                  return controller.formatDate(timestamp.millisecondsSinceEpoch);
                                                },
                                                formatStatus: controller.formatStatus,
                                                firestore: FirebaseFirestore.instance,
                                                getOrderProductDoc: controller.getOrderProductDoc,
                                              ),
                                            ),
                                          ).then((_) {
                                            controller.loadReturns();
                                          });
                                        }
                                        else if (value == 'delete') {
                                          showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text('Delete Return'),
                                              content: const Text('Are you sure you want to delete this return?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    Navigator.pop(context);
                                                    await FirebaseFirestore.instance
                                                        .collection('returnRequests')
                                                        .doc(item['id'])
                                                        .delete();
                                                    controller.loadReturns();
                                                  },
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                        } else {
                                          controller.updateReturnStatus(context, item['userEmail'], item['id'], value);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'view', child: Text('View Details')),
                                        PopupMenuDivider(),
                                        PopupMenuItem(value: 'delete', child: Text('Delete Return', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                        // Pagination
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Showing ${startIndex + 1} to ${endIndex} of ${controller.filteredReturns.length} items'),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: controller.currentPage > 1
                                        ? () => controller.currentPage--
                                        : null,
                                  ),
                                  ...List.generate(
                                    totalPages > 5 ? 5 : totalPages,
                                        (index) {
                                      final page = index + 1;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: ElevatedButton(
                                          onPressed: () => controller.currentPage = page,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: controller.currentPage == page
                                                ? const Color(0xFF7C3AED)
                                                : Colors.grey[300],
                                            minimumSize: const Size(40, 40),
                                          ),
                                          child: Text(
                                            '$page',
                                            style: TextStyle(
                                              color: controller.currentPage == page ? Colors.white : Colors.black,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: controller.currentPage < totalPages
                                        ? () => controller.currentPage++
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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


  Widget _buildFilterTab(BuildContext context, String title) {
    final controller = context.read<ReturnManagementController>();
    final isActive = controller.selectedTab == title;

    return InkWell(
      onTap: () {
        controller.selectedTab = title;
        controller.filterReturns();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF7C3AED) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFF7C3AED) : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
