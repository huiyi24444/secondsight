import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
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

    await loadReturnData();

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
        _loadOrderDetails(orderID, userID),
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
  Future<void> _loadOrderDetails(String? orderID, String? userID) async {
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
      }
    } catch (e) {
      // Handle error silently or use proper error logging
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
    if (userID == null || userID.isEmpty) return;

    try {
      final customerDoc = await firestore
          .collection('customers')
          .doc(userID)
          .get();

      if (customerDoc.exists) {
        _customerDetails = customerDoc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      // Handle error silently or use proper error logging
    }
  }

  /// Update return status
  Future<bool> updateReturnStatus(String returnId, String newStatus) async {
    try {
      await firestore
          .collection('returnRequests')
          .doc(returnId)
          .update({
        'returnStatus': newStatus,
        '${newStatus}Date': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete return request
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

    final firstName = _customerDetails!['firstName'] ?? '';
    final lastName = _customerDetails!['lastName'] ?? '';

    return '$firstName $lastName'.trim();
  }

  /// Get customer phone number
  String getCustomerPhone() {
    return _customerDetails?['phoneNumber'] ?? 'N/A';
  }

  /// Get formatted order ID (shortened)
  String getShortOrderId() {
    final orderId = returnRequest.orderID;
    return orderId.length > 8 ? orderId.substring(0, 8) : orderId;
  }

  /// Get return timeline data
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

    // Add completed step if applicable
    if (returnRequest.completedDate != null) {
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
    return returnRequest.returnStatus == 'completed';
  }

  @override
  void dispose() {
    super.dispose();
  }
}