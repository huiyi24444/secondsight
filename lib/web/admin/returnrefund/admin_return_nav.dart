// File: return_navigation_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/view/widgets/return_status_utils.dart';
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
  bool handleKeyEvent(KeyEvent event, String currentStatus, Function(String?) handleStatusChange) {
    if (event is KeyDownEvent) {
      // Navigate to previous return with Left Arrow or P key
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.keyP) {
        if (currentIndex > 0) {
          navigateToPrevious();
          return true;
        }
      }

      // Navigate to next return with Right Arrow or N key
      if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.keyN) {
        if (currentIndex < allReturns.length - 1) {
          navigateToNext();
          return true;
        }
      }
    }

    return false;
  }
}