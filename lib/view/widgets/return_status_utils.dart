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
      case 'completed':
        return 'Completed';
      case 'pending_inspection':
        return 'Pending Inspection';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }


  static Color getReturnStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'submitted':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.teal;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  /// Get config for return status progress stepper
  static Map<String, dynamic> getReturnStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'pending_approval':
        return {
          'title': 'Return In Progress',
          'steps': ['Pending Approval', 'Approval Results', 'Processing', 'Completed'],
          'currentStep': 0,
        };
      case 'approved':
        return {
          'title': 'Return Approved',
          'steps': ['Pending Approval', 'Approved', 'Processing', 'Completed'],
          'currentStep': 1,
        };
      case 'pending_inspection':
        return {
          'title': 'Pending Inspection',
          'steps': ['Pending Review', 'Approved', 'Processing', 'Completed'],
          'currentStep': 2,
        };
      case 'completed':
        return {
          'title': 'Return Completed',
          'steps': ['Pending Review', 'Approved', 'Processing', 'Completed'],
          'currentStep': 3,
        };
      case 'rejected':
        return {
          'title': 'Return Rejected',
          'steps': ['Pending Approval', 'Rejected'],
          'currentStep': 1,
        };
      default:
        return {
          'title': 'Return Status',
          'steps': ['Pending Approval', 'Under Review', 'Processing', 'Completed'],
          'currentStep': 0,
        };
    }
  }

  static ReturnStatus _getStatusFromRequest(ReturnRequestModel request) {
    // Convert your request status to ReturnStatus enum
    switch (request.returnStatus?.toLowerCase()) {
      case 'approved':
        return ReturnStatus.approved;
      case 'pending_inspection':
        return ReturnStatus.pending_inspection;
      case 'completed':
        return ReturnStatus.completed;
      case 'pending_approval':
        return ReturnStatus.pending_approval;
      default:
        return ReturnStatus.pending_approval;
    }
  }
}
