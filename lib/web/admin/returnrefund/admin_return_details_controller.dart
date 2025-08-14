// admin_return_details_controller.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/controller/order/notif_controller.dart';
import 'package:secondsight/view/widgets/product_status_utils.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../../../model/refund_model.dart';
import '../../../model/return_request_model.dart';

class AdminReturnDetailsController extends ChangeNotifier {
  final ReturnRequestModel returnRequest;
  final FirebaseFirestore firestore;
  final Future<DocumentSnapshot?> Function(String, String, String) getOrderProductDoc;

  // State variables
  bool _isLoading = true;
  OrdersModel? _order;
  OrderProductModel? _orderProduct;
  Map<String, dynamic>? _productDetails;
  Map<String, dynamic>? _customerDetails;

  // Getters
  bool get isLoading => _isLoading;
  OrdersModel? get order => _order;
  OrderProductModel? get orderProduct => _orderProduct;
  Map<String, dynamic>? get productDetails => _productDetails;
  Map<String, dynamic>? get customerDetails => _customerDetails;

  AdminReturnDetailsController({
    required this.returnRequest,
    required this.firestore,
    required this.getOrderProductDoc,
  });

  /// Initialize and load all return-related data
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([
      loadReturnData(),
      _loadCustomerDetails(returnRequest.userID),
      loadOrderDetails(returnRequest.orderID, returnRequest.userID),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  /// Load all return-related data including order, product, and customer details
  Future<void> loadReturnData() async {
    try {
      final orderID = returnRequest.orderID;
      final userID = returnRequest.userID;
      final orderProductID = returnRequest.orderProductID;

      // Load data concurrently for better performance
      await Future.wait([
        loadOrderDetails(orderID, userID),
        _loadOrderProductDetails(userID, orderID, orderProductID),
        _loadCustomerDetails(userID),
      ]);
    } catch (e) {
      // Handle error silently or use proper error logging
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load order details from Firestore
  Future<void> loadOrderDetails(String? orderID, String? userID) async {
    if (orderID == null || orderID.isEmpty || userID == null || userID.isEmpty) {
      return;
    }

    try {
      final orderDoc = await firestore
          .collection('users')
          .doc(userID)
          .collection('order')
          .doc(orderID)
          .get();

      if (orderDoc.exists) {
        _order = OrdersModel.fromJson(
          orderDoc.data() as Map<String, dynamic>,
          orderDoc.id,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading order details: $e');
    }
  }

  /// Load order product details and associated product information
  Future<void> _loadOrderProductDetails(
      String? userID,
      String? orderID,
      String? orderProductID,
      ) async {
    if (userID == null || userID.isEmpty ||
        orderID == null || orderID.isEmpty ||
        orderProductID == null || orderProductID.isEmpty) {
      return;
    }

    try {
      final orderProductDoc = await getOrderProductDoc(
        userID,
        orderID,
        orderProductID,
      );

      if (orderProductDoc != null && orderProductDoc.exists) {
        _orderProduct = OrderProductModel.fromJson(
          orderProductDoc.data() as Map<String, dynamic>,
        );

        // Load associated product details
        await _loadProductDetails();
      }
    } catch (e) {
      // Handle error silently or use proper error logging
    }
  }

  /// Load product details from product reference
  Future<void> _loadProductDetails() async {
    if (_orderProduct?.productID == null) return;

    try {
      final productRef = _orderProduct!.productID as DocumentReference;
      final productDoc = await productRef.get();

      if (productDoc.exists) {
        _productDetails = productDoc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      _productDetails = null;
    }
  }

  /// Load customer details from Firestore
  Future<void> _loadCustomerDetails(String? userID) async {
    if (userID == null || userID.isEmpty) {
      print('[DEBUG] UserID is null or empty. Aborting fetch.');
      return;
    }

    print('[DEBUG] Fetching customer details for userID: $userID');

    try {
      final customerDoc = await firestore
          .collection('users')
          .doc(userID)
          .get();

      if (customerDoc.exists) {
        _customerDetails = customerDoc.data() as Map<String, dynamic>;
        print('[DEBUG] Customer data retrieved: $_customerDetails');
      } else {
        print('[DEBUG] No customer document found for userID: $userID');
      }
    } catch (e) {
      print('[ERROR] Failed to load customer details for userID: $userID. Error: $e');
    }
  }

  Future<RefundModel?> loadRefundDetails(String? refundID) async {
    if (refundID == null || refundID.isEmpty) {
      return null;
    }

    try {
      final refundDoc = await firestore
          .collection('refunds')
          .doc(refundID)
          .get();

      if (refundDoc.exists) {
        return RefundModel.fromDocument(refundDoc);
      }
      return null;
    } catch (e) {
      debugPrint('Error loading refund details: $e');
      return null;
    }
  }

  String formatRefundType(String refundType) {
    switch (refundType.toLowerCase()) {
      case 'return':
        return 'Return Refund';
      case 'cancellation':
        return 'Order Cancellation';
      case 'partial':
        return 'Partial Refund';
      default:
        return refundType.substring(0, 1).toUpperCase() + refundType.substring(1);
    }
  }

  /// Create notification for return status update


  /// Format return status for display
  String formatReturnStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending_inspection':
        return 'Pending Inspection';
      case 'completed_inspection':
        return 'Inspection Completed';
      case 'refunded':
        return 'Refunded';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.substring(0, 1).toUpperCase() + status.substring(1);
    }
  }

  /// Update return status (original method kept for backward compatibility)
  Future<bool> updateReturnStatus(String returnId, String newStatus) async {
    try {
      // Get current return request to check current status
      final returnDoc = await firestore
          .collection('returnRequests')
          .doc(returnId)
          .get();

      if (!returnDoc.exists) {
        throw Exception('Return request not found');
      }

      final returnData = returnDoc.data() as Map<String, dynamic>;
      final currentStatus = returnData['returnStatus'] as String;

      // Validate status transition based on workflow
      if (!_isValidStatusTransition(currentStatus, newStatus)) {
        throw Exception('Invalid status transition from $currentStatus to $newStatus');
      }

      // Special handling for different status transitions
      switch (newStatus) {
        case 'approved':
          await _handleApprovedStatus(returnId, returnData);
          break;
        case 'rejected':
          await _handleRejectedStatus(returnId, returnData);
          break;
        case 'pending_inspection':
          await _handlePendingInspectionStatus(returnId, returnData);
          break;
        case 'completed_inspection':
          await _handleCompletedInspectionStatus(returnId, returnData);
          break;
        case 'refunded':
          await _handleRefundedStatus(returnId, returnData);
          break;
        case 'not_refunded':
          await _handleNotRefundedStatus(returnId, returnData);
          break;
        case 'cancelled':
          await _handleCancelledStatus(returnId, returnData);
          break;
        default:
        // Standard status update for other statuses
          await _updateReturnStatusOnly(returnId, newStatus);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating return status: $e');
      return false;
    }
  }


  /// Validate if status transition is allowed based on workflow
  bool _isValidStatusTransition(String currentStatus, String newStatus) {
    // Define allowed transitions based on your workflow
    final Map<String, List<String>> allowedTransitions = {
      'pending_approval': ['approved', 'rejected', 'cancelled'],
      'approved': ['pending_inspection'],
      'rejected': [], // No further transitions allowed
      'pending_inspection': ['completed_inspection'],
      'completed_inspection': ['refunded', 'not_refunded'],
      'refunded': [], // Final status - no further transitions
      'not_refunded': [], // Final status - no further transitions
      'cancelled': [], // Final status - no further transitions
    };

    // Special case: allow same status (no change)
    if (currentStatus == newStatus) {
      return true;
    }

    final allowedNextStatuses = allowedTransitions[currentStatus] ?? [];
    return allowedNextStatuses.contains(newStatus);
  }

  /// Handle approved status transition - WITH DEBUGGING
  /// Handle approved status transition - WITH PROPER ERROR HANDLING
  Future<void> _handleApprovedStatus(String returnId, Map<String, dynamic> returnData) async {
    debugPrint('🔍 [DEBUG] Return data keys: ${returnData.keys.toList()}');
    debugPrint('🔍 [DEBUG] Full return data: $returnData');

    final userID = returnData['userID'];
    final productID = returnData['productID'];
    final orderID = returnData['orderID'];

    debugPrint('🔍 [DEBUG] userID: $userID');
    debugPrint('🔍 [DEBUG] productID: $productID');
    debugPrint('🔍 [DEBUG] orderID: $orderID');

    if (userID == null || productID == null) {
      debugPrint('❌ [ERROR] Missing required fields: userID=$userID, productID=$productID');
      throw Exception('Missing required notification data: userID or productID is null');
    }

    // Create notification with proper error handling
    try {
      debugPrint('🔔 [NOTIFICATION] Attempting to create notification...');

      await NotificationController.createReturnNotification(
        returnId: returnId,
        newStatus: 'approved',
        userId: userID,
        productId: productID,
        orderId: orderID,
      );

      debugPrint('✅ [SUCCESS] Notification created successfully');
    } catch (notificationError) {
      debugPrint('❌ [NOTIFICATION ERROR] Failed to create notification: $notificationError');
    }

    // Update status with proper date tracking
    try {
      debugPrint('📝 [STATUS] Updating return status to approved...');

      await firestore
          .collection('returnRequests')
          .doc(returnId)
          .update({
        'returnStatus': 'approved',
        'approvedDate': FieldValue.serverTimestamp(), // Set the approvedDate
      });

      debugPrint('✅ [SUCCESS] Status updated successfully');
    } catch (statusError) {
      debugPrint('❌ [STATUS ERROR] Failed to update status: $statusError');
      rethrow;
    }
  }




  /// Handle rejected status transition - WITH PROPER DATE TRACKING
  Future<void> _handleRejectedStatus(String returnId, Map<String, dynamic> returnData) async {
    final userID = returnData['userID'];
    final productID = returnData['productID'];
    final orderID = returnData['orderID'];

    // Create notification
    await NotificationController.createReturnNotification(
      returnId: returnId,
      newStatus: 'rejected',
      userId: userID,
      productId: productID,
      orderId: orderID,
    );

    // Update status with proper date tracking
    await firestore
        .collection('returnRequests')
        .doc(returnId)
        .update({
      'returnStatus': 'rejected',
      'rejectedDate': FieldValue.serverTimestamp(), // Set the rejectedDate
    });
  }

  /// Handle pending inspection status transition - WITH PROPER DATE TRACKING
  Future<void> _handlePendingInspectionStatus(String returnId, Map<String, dynamic> returnData) async {
    final userID = returnData['userID'];
    final productID = returnData['productID'];
    final orderID = returnData['orderID'];

    // Create notification
    await NotificationController.createReturnNotification(
      returnId: returnId,
      newStatus: 'pending_inspection',
      userId: userID,
      productId: productID,
      orderId: orderID,
    );

    // Update status with proper date tracking
    await firestore
        .collection('returnRequests')
        .doc(returnId)
        .update({
      'returnStatus': 'pending_inspection',
      'pendinginspectionDate': FieldValue.serverTimestamp(), // Set the pendinginspectionDate
    });
  }
  Future<void> _handleCompletedInspectionStatus(String returnId, Map<String, dynamic> returnData) async {
    final userID = returnData['userID'];
    final productID = returnData['productID'];
    final orderID = returnData['orderID'];

    // Create notification
    await NotificationController.createReturnNotification(
      returnId: returnId,
      newStatus: 'completed_inspection',
      userId: userID,
      productId: productID,
      orderId: orderID,
    );

    // Update status with proper date tracking
    await firestore
        .collection('returnRequests')
        .doc(returnId)
        .update({
      'returnStatus': 'completed_inspection',
      'completedinsepectionDate': FieldValue.serverTimestamp(), // Set the completedinsepectionDate
    });
  }

  /// Handle refunded status transition - WITH PROPER DATE TRACKING
  Future<void> _handleRefundedStatus(String returnId, Map<String, dynamic> returnData) async {
    final userID = returnData['userID'];
    final productID = returnData['productID'];
    final orderID = returnData['orderID'];
    final refundAmount = (returnData['returnPrice'] ?? 0.0) as double;
    final returnQuantity = returnData['returnQuantity'] ?? 1;
    final totalRefundAmount = refundAmount * returnQuantity;

    // Get payment method from original order
    final orderDoc = await firestore
        .collection('users')
        .doc(userID)
        .collection('order')
        .doc(orderID)
        .get();

    final paymentMethod = orderDoc.exists
        ? (orderDoc.data() as Map<String, dynamic>)['paymentMethod'] ?? 'Original Payment Method'
        : 'Original Payment Method';

    final payment = orderDoc.exists
        ? (orderDoc.data() as Map<String, dynamic>)['payment'] ?? 'Unknown'
        : 'Unknown';

    // Create refund document reference
    final refundRef = firestore.collection('refunds').doc();

    // Prepare refund data
    final refundData = {
      'orderId': orderID,
      'productID': productID,
      'returnRequestId': returnId,
      'cancelId': null,
      'refundAmount': totalRefundAmount,
      'refundMethod': paymentMethod,
      'refundDate': FieldValue.serverTimestamp(),
      'transactionId': payment,
      'customerId': userID,
      'refundType': 'return',
    };

    // Create notification
    await NotificationController.createReturnNotification(
      returnId: returnId,
      newStatus: 'refunded',
      userId: userID,
      productId: productID,
      orderId: orderID,
    );

    // Use batch write for atomicity
    final batch = firestore.batch();

    // Update return request status with proper date tracking
    batch.update(
      firestore.collection('returnRequests').doc(returnId),
      {
        'returnStatus': 'refunded',
        'refundedDate': FieldValue.serverTimestamp(), // Set the refundedDate (custom field)
        'completedDate': FieldValue.serverTimestamp(), // Also set completedDate since refund completes the process
        'refundID': refundRef.id,
      },
    );

    // Create refund document
    batch.set(refundRef, refundData);

    // Commit batch
    await batch.commit();
  }

  /// Handle not refunded status transition - WITH PROPER DATE TRACKING
  Future<void> _handleNotRefundedStatus(String returnId, Map<String, dynamic> returnData) async {
    final userID = returnData['userID'];
    final productID = returnData['productID'];
    final orderID = returnData['orderID'];

    // Create notification
    await NotificationController.createReturnNotification(
      returnId: returnId,
      newStatus: 'not_refunded',
      userId: userID,
      productId: productID,
      orderId: orderID,
    );

    // Update status with proper date tracking
    await firestore
        .collection('returnRequests')
        .doc(returnId)
        .update({
      'returnStatus': 'not_refunded',
      'completedDate': FieldValue.serverTimestamp(), // Set completedDate since process is finished
      'notRefundedDate': FieldValue.serverTimestamp(), // Custom field for not refunded date
    });
  }

  /// Handle cancelled status transition - WITH PROPER DATE TRACKING
  Future<void> _handleCancelledStatus(String returnId, Map<String, dynamic> returnData) async {
    final userID = returnData['userID'];
    final productID = returnData['productID'];
    final orderID = returnData['orderID'];

    // Create cancellation document reference
    final cancellationRef = firestore.collection('cancellation').doc();

    // Prepare cancellation data
    final cancellationData = {
      'referenceID': returnId,
      'cancellationType': 'return_request',
      'cancelReason': 'Return request cancelled by admin',
      'cancelDate': FieldValue.serverTimestamp(),
      'cancelNote': null,
      'cancelledBy': 'admin',
      'returnRequestID': returnId,
    };

    // Create notification
    await NotificationController.createReturnNotification(
      returnId: returnId,
      newStatus: 'cancelled',
      userId: userID,
      productId: productID,
      orderId: orderID,
    );

    // Use batch write for atomicity
    final batch = firestore.batch();

    // Create cancellation document
    batch.set(cancellationRef, cancellationData);

    // Update return request status with proper date tracking
    batch.update(
      firestore.collection('returnRequests').doc(returnId),
      {
        'returnStatus': 'cancelled',
        'cancelledDate': FieldValue.serverTimestamp(), // Set the cancelledDate
        'cancelID': cancellationRef.id,
      },
    );

    // Commit batch
    await batch.commit();
  }

  /// Standard status update with timestamp
  /// REPLACE the existing _updateReturnStatusOnly method with this enhanced version
  Future<void> _updateReturnStatusOnly(String returnId, String newStatus) async {
    Map<String, dynamic> updateData = {
      'returnStatus': newStatus,
    };

    // Add specific date fields based on status
    switch (newStatus.toLowerCase()) {
      case 'pending':
      case 'pending_approval':
        updateData['pendingDate'] = FieldValue.serverTimestamp();
        break;
      case 'approved':
        updateData['approvedDate'] = FieldValue.serverTimestamp();
        break;
      case 'rejected':
        updateData['rejectedDate'] = FieldValue.serverTimestamp();
        break;
      case 'pending_inspection':
        updateData['pendinginspectionDate'] = FieldValue.serverTimestamp();
        break;
      case 'completed_inspection':
        updateData['completedinsepectionDate'] = FieldValue.serverTimestamp();
        break;
      case 'completed':
        updateData['completedDate'] = FieldValue.serverTimestamp();
        break;
      case 'cancelled':
        updateData['cancelledDate'] = FieldValue.serverTimestamp();
        break;
      case 'refunded':
        updateData['completedDate'] = FieldValue.serverTimestamp();
        // Note: refundedDate would be set in the specific handler method
        break;
      case 'not_refunded':
        updateData['completedDate'] = FieldValue.serverTimestamp();
        updateData['notRefundedDate'] = FieldValue.serverTimestamp();
        break;
    }

    await firestore
        .collection('returnRequests')
        .doc(returnId)
        .update(updateData);
  }
  /// Get allowed next statuses for current status (for UI dropdown)
  List<String> getAllowedNextStatuses(String currentStatus) {
    final Map<String, List<String>> allowedTransitions = {
      'pending_approval': ['approved', 'rejected', 'cancelled'],
      'approved': ['pending_inspection'],
      'rejected': [],
      'pending_inspection': ['completed_inspection'],
      'completed_inspection': ['refunded', 'not_refunded'],
      'refunded': [],
      'not_refunded': [],
      'cancelled': [],
    };

    return allowedTransitions[currentStatus] ?? [];
  }

  /// Delete return request (original method kept for backward compatibility)
  Future<bool> deleteReturnRequest(String returnId) async {
    try {
      await firestore
          .collection('returnRequests')
          .doc(returnId)
          .delete();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get formatted customer name
  String getCustomerName() {
    if (_customerDetails == null) return 'N/A';
    final fullName = _customerDetails!['fullName'] ?? '';
    return '$fullName';
  }

  /// Get customer phone number
  String getCustomerPhone() {
    return _customerDetails?['phoneNum']?.toString() ?? 'N/A';
  }

  /// Get formatted order ID (shortened)
  String getShortOrderId() {
    final orderId = returnRequest.orderID;
    return (orderId.length > 6 ? orderId.substring(0, 6) : orderId).toUpperCase();
  }

  /// Get return timeline data
  /// Get return timeline data - FIXED REFUND LOGIC
  List<Map<String, dynamic>> getReturnTimeline() {
    final List<Map<String, dynamic>> timeline = [];

    // Always show pending as the first step
    timeline.add({
      'title': 'Return Requested',
      'date': returnRequest.pendingDate != null
          ? returnRequest.pendingDate!
          : returnRequest.returnDate,
      'icon': Icons.refresh,
      'color': Colors.blue,
      'isCompleted': true,
    });

    // Add approved step if applicable
    if (returnRequest.approvedDate != null) {
      timeline.add({
        'title': 'Return Approved',
        'date': returnRequest.approvedDate!,
        'icon': Icons.check_circle,
        'color': Colors.green,
        'isCompleted': true,
      });
    }

    // Add rejected step if applicable
    if (returnRequest.rejectedDate != null) {
      timeline.add({
        'title': 'Return Rejected',
        'date': returnRequest.rejectedDate!,
        'icon': Icons.cancel,
        'color': Colors.red,
        'isCompleted': true,
      });
    }

    // Add pending inspection step if applicable
    if (returnRequest.pendinginspectionDate != null) {
      timeline.add({
        'title': 'Pending Inspection',
        'date': returnRequest.pendinginspectionDate!,
        'icon': Icons.search,
        'color': Colors.orange,
        'isCompleted': true,
      });
    }

    // Add completed inspection step if applicable
    if (returnRequest.completedinsepectionDate != null) {
      timeline.add({
        'title': 'Inspection Completed',
        'date': returnRequest.completedinsepectionDate!,
        'icon': Icons.verified,
        'color': Colors.teal,
        'isCompleted': true,
      });
    }

    // FIXED: Add refunded step ONLY when status is actually 'refunded' AND refundID exists
    if (returnRequest.returnStatus.toLowerCase() == 'refunded' &&
        returnRequest.refundID != null &&
        returnRequest.refundID!.isNotEmpty) {
      timeline.add({
        'title': 'Refund Processed',
        'date': returnRequest.completedDate ?? DateTime.now(),
        'icon': Icons.attach_money,
        'color': Colors.green[700]!,
        'isCompleted': true,
      });
    }

    // FIXED: Add not refunded step if applicable
    if (returnRequest.returnStatus.toLowerCase() == 'not_refunded') {
      timeline.add({
        'title': 'Not Refunded',
        'date': returnRequest.completedDate ?? DateTime.now(),
        'icon': Icons.money_off,
        'color': Colors.orange[700]!,
        'isCompleted': true,
      });
    }

    // FIXED: Add completed step ONLY when completed but NOT refunded/not_refunded
    if (returnRequest.completedDate != null &&
        returnRequest.returnStatus.toLowerCase() != 'refunded' &&
        returnRequest.returnStatus.toLowerCase() != 'not_refunded') {
      timeline.add({
        'title': 'Return Completed',
        'date': returnRequest.completedDate!,
        'icon': Icons.done_all,
        'color': Colors.green,
        'isCompleted': true,
      });
    }

    // Add cancelled step if applicable
    if (returnRequest.cancelledDate != null) {
      timeline.add({
        'title': 'Return Cancelled',
        'date': returnRequest.cancelledDate!,
        'icon': Icons.block,
        'color': Colors.grey,
        'isCompleted': true,
      });
    }

    return timeline;
  }

  /// Calculate total return price
  double getTotalReturnPrice() {
    return returnRequest.returnPrice * returnRequest.returnQuantity;
  }

  /// Get clean product image URL
  String getCleanImageUrl() {
    return returnRequest.productImageUrl
        .trim()
        .replaceAll('\n', '')
        .replaceAll('\r', '');
  }

  /// Check if refund is completed
  bool isRefundCompleted() {
    return returnRequest.returnStatus == 'refunded' || returnRequest.returnStatus == 'completed';
  }

  @override
  void dispose() {
    super.dispose();
  }
}