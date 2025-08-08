import 'dart:ui';

import 'package:flutter/material.dart';

import '../../model/return_request_model.dart';
import '../returnRefund/return_status.dart';

class ReturnStatusUtils {
  /// Get readable display text for a return status code
  static String getReturnStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending_approval':
        return 'Pending Approval';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'completed_inspection':
        return 'Completed';
      case 'pending_inspection':
        return 'Pending Inspection';
      case 'refunded':
        return 'Refunded';
      case 'not_refunded':
        return 'Not Refunded'; // <-- Add this case
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }


  static Color getReturnStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending_approval':
        return Colors.orange; // Initial step
      case 'approved':
        return Colors.blue; // Approval given
      case 'pending_inspection':
        return Colors.amber; // Awaiting inspection
      case 'completed_inspection':
        return Colors.teal; // Done inspecting
      case 'refunded':
        return Colors.green; // Refund completed
      case 'not_refunded':
        return Colors.deepPurple; // Completed but no refund
      case 'rejected':
        return Colors.red; // Rejected during approval
      case 'cancelled':
        return Colors.grey; // User-initiated cancel before approval
      default:
        return Colors.black; // Unknown or fallback
    }
  }

  static Map<String, dynamic> getReturnStatusConfig(String status) {
    final steps = [
      'Pending Approval',
      'Approved',
      'Pending Inspection',
      'Completed Inspection',
      'Refunded / Not Refunded',
    ];

    switch (status.toLowerCase()) {
      case 'pending_approval':
        return {
          'title': 'Awaiting Approval',
          'steps': steps,
          'currentStep': 0,
        };
      case 'approved':
        return {
          'title': 'Return Approved',
          'steps': steps,
          'currentStep': 1,
        };
      case 'pending_inspection':
        return {
          'title': 'Pending Inspection',
          'steps': steps,
          'currentStep': 2,
        };
      case 'completed_inspection':
        return {
          'title': 'Inspection Completed',
          'steps': steps,
          'currentStep': 3,
        };
      case 'refunded':
        return {
          'title': 'Refunded',
          'steps': steps,
          'currentStep': 4,
        };
      case 'not_refunded':
        return {
          'title': 'Not Refunded',
          'steps': steps,
          'currentStep': 4,
        };
      case 'rejected':
        return {
          'title': 'Return Rejected',
          'steps': ['Pending Approval', 'Rejected'],
          'currentStep': 1,
        };
      case 'cancelled':
        return {
          'title': 'Return Cancelled',
          'steps': ['Pending Approval', 'Cancelled'],
          'currentStep': 1,
        };
      default:
        return {
          'title': 'Return Status',
          'steps': steps,
          'currentStep': 0,
        };
    }
  }

  static ReturnStatus _getStatusFromRequest(ReturnRequestModel request) {
    switch (request.returnStatus?.toLowerCase()) {
      case 'pending_approval':
        return ReturnStatus.pending_approval;
      case 'approved':
        return ReturnStatus.approved;
      case 'pending_inspection':
        return ReturnStatus.pending_inspection;
      case 'completed_inspection':
        return ReturnStatus.completed_inspection;
      case 'refunded':
        return ReturnStatus.refunded;
      case 'not_refunded':
        return ReturnStatus.not_refunded;
      case 'rejected':
        return ReturnStatus.rejected;
      case 'cancelled':
        return ReturnStatus.cancelled;
      default:
        return ReturnStatus.pending_approval;
    }
  }

  static String shortReturnId(String? id) {
    final safeId = id ?? '';
    return safeId.length >= 8
        ? safeId.substring(0, 8).toUpperCase()
        : safeId.toUpperCase();
  }


}
