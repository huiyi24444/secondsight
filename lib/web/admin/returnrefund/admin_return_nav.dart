// File: return_navigation_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../model/return_request_model.dart';
import 'admin_return_details.dart';

class ReturnNavigationService {
  final List<Map<String, dynamic>> allReturns;
  final int currentIndex;
  final String? selectedFilter;
  final BuildContext context;
  final Future<bool> Function(String, String) onUpdateReturnStatus;
  final String Function(Timestamp) formatDate;
  final String Function(String) formatStatus;
  final FirebaseFirestore firestore;
  final Future<DocumentSnapshot?> Function(String, String, String) getOrderProductDoc;

  ReturnNavigationService({
    required this.allReturns,
    required this.currentIndex,
    required this.selectedFilter,
    required this.context,
    required this.onUpdateReturnStatus,
    required this.formatDate,
    required this.formatStatus,
    required this.firestore,
    required this.getOrderProductDoc,
  });

  // Navigation methods
  void navigateToPrevious() {
    if (currentIndex > 0) {
      final previousReturn = allReturns[currentIndex - 1];
      final previousReturnRequest = previousReturn['returnRequest'] as ReturnRequestModel;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReturnDetailsPage(
            returnRequest: previousReturnRequest,
            onUpdateReturnStatus: onUpdateReturnStatus,
            formatDate: formatDate,
            formatStatus: formatStatus,
            firestore: firestore,
            getOrderProductDoc: getOrderProductDoc,
            allReturns: allReturns,
            currentIndex: currentIndex - 1,
            selectedFilter: selectedFilter,
          ),
        ),
      );
    }
  }

  void navigateToNext() {
    if (currentIndex < allReturns.length - 1) {
      final nextReturn = allReturns[currentIndex + 1];
      final nextReturnRequest = nextReturn['returnRequest'] as ReturnRequestModel;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReturnDetailsPage(
            returnRequest: nextReturnRequest,
            onUpdateReturnStatus: onUpdateReturnStatus,
            formatDate: formatDate,
            formatStatus: formatStatus,
            firestore: firestore,
            getOrderProductDoc: getOrderProductDoc,
            allReturns: allReturns,
            currentIndex: currentIndex + 1,
            selectedFilter: selectedFilter,
          ),
        ),
      );
    }
  }

  // Quick action methods
  Future<void> quickApprove(String currentStatus, Function(String?) handleStatusChange) async {
    if (currentStatus == 'submitted' || currentStatus == 'pending') {
      await handleStatusChange('approved');
    }
  }

  Future<void> quickReject(String currentStatus, Function(String?) handleStatusChange) async {
    if (currentStatus == 'submitted' || currentStatus == 'pending') {
      await showRejectDialog(handleStatusChange);
    }
  }

  Future<void> quickComplete(String currentStatus, Function(String?) handleStatusChange) async {
    if (currentStatus == 'pending_inspection') {
      await handleStatusChange('completed');
    }
  }

  Future<void> quickCancel(String currentStatus, Function(String?) handleStatusChange) async {
    if (currentStatus == 'pending_inspection') {
      await handleStatusChange('cancelled');
    }
  }

  Future<void> showRejectDialog(Function(String?) handleStatusChange) async {
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Return Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result == true && reasonController.text.isNotEmpty) {
      await handleStatusChange('rejected');
      // TODO: Save rejection reason to Firestore
    }
  }

  // Keyboard shortcut handler
  bool handleKeyEvent(KeyEvent event, String currentStatus, Function(String?) handleStatusChange) {
    if (event is KeyDownEvent) {
      // Navigation shortcuts
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.keyP) {
        navigateToPrevious();
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.keyN) {
        navigateToNext();
        return true;
      }

      // Quick action shortcuts
      if (event.logicalKey == LogicalKeyboardKey.keyA) {
        quickApprove(currentStatus, handleStatusChange);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        quickReject(currentStatus, handleStatusChange);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        quickComplete(currentStatus, handleStatusChange);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyX) {
        quickCancel(currentStatus, handleStatusChange);
        return true;
      }

      // Escape to go back
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.pop(context);
        return true;
      }
    }
    return false;
  }

  // Build navigation header widget
  Widget buildNavigationHeader(String returnId, String currentStatus, Function(String?) handleStatusChange) {
    final hasFilter = selectedFilter != null && selectedFilter != 'All';
    final filterText = hasFilter ? ' ($selectedFilter)' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to List (Esc)',
          ),

          const SizedBox(width: 16),

          // Status indicator
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Return #${returnId.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${currentIndex + 1} of ${allReturns.length}$filterText',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Quick action buttons
          if (currentStatus == 'submitted' || currentStatus == 'pending') ...[
            ElevatedButton.icon(
              onPressed: () => quickApprove(currentStatus, handleStatusChange),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Approve (A)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => quickReject(currentStatus, handleStatusChange),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Reject (R)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],

          if (currentStatus == 'pending_inspection') ...[
            ElevatedButton.icon(
              onPressed: () => quickComplete(currentStatus, handleStatusChange),
              icon: const Icon(Icons.check_circle, size: 16),
              label: const Text('Complete (C)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => quickCancel(currentStatus, handleStatusChange),
              icon: const Icon(Icons.cancel, size: 16),
              label: const Text('Cancel (X)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],

          const SizedBox(width: 16),

          // Navigation buttons
          IconButton(
            onPressed: currentIndex > 0 ? navigateToPrevious : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous (← or P)',
            iconSize: 28,
          ),
          IconButton(
            onPressed: currentIndex < allReturns.length - 1 ? navigateToNext : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next (→ or N)',
            iconSize: 28,
          ),
        ],
      ),
    );
  }
}