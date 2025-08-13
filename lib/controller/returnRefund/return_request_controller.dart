// return_request_controller.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:secondsight/controller/order/notif_controller.dart';
import 'dart:io';
import '../../model/return_request_model.dart';
import '../../model/order_product_model.dart';

class ReturnRequestController extends ChangeNotifier {
  final String orderId;
  final String userId;
  final String orderProductId;
  final String? existingReturnRequestId;

  // Controllers
  final TextEditingController descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // State variables
  String selectedReason = 'Item Defect';
  List<XFile> selectedImages = [];
  List<String> uploadedImageUrls = [];
  bool isSubmitting = false;
  bool isUploadingImages = false;
  bool hasExistingReturnRequest = false;

  // Data
  OrderProductModel? orderProduct;
  Map<String, dynamic>? productData;
  ReturnRequestModel? returnRequest;
  String? productDocumentId;

  final List<String> returnReasons = [
    'Item Defect',
    'Wrong Size',
    'Not as Described',
    'Damaged During Shipping',
    'Changed Mind',
    'Poor Quality',
    'Other',
  ];

  ReturnRequestController({
    required this.orderId,
    required this.userId,
    required this.orderProductId,
    this.existingReturnRequestId,
  });

  // Getters for view
  bool get isViewingExistingRequest => existingReturnRequestId != null;

  String get productURL {
    // When viewing existing return, use denormalized data
    if (returnRequest != null) {
      return returnRequest!.productImageUrl;
    }

    // When creating new return, use product data
    final productURLList = productData?['productURL'];
    return (productURLList is List && productURLList.isNotEmpty)
        ? productURLList.first.toString()
        : '';
  }

  String get productName {
    // When viewing existing return, use denormalized data
    if (returnRequest != null) {
      return returnRequest!.productName;
    }

    // When creating new return, use product data
    return productData?['productName'] ?? 'Unknown Product';
  }

  String get productID {
    // When viewing existing return, use denormalized data
    if (returnRequest != null) {
      return returnRequest!.productID;
    }

    // When creating new return, use the document ID from DocumentReference
    return productDocumentId ?? 'Unknown Product ID';
  }

  int get quantity {
    // When viewing existing return, use denormalized data
    if (returnRequest != null) {
      return returnRequest!.returnQuantity;
    }

    // When creating new return, use order product data
    return orderProduct?.productQuantity ?? 1;
  }

  Future<void> checkExistingReturnRequest() async {
    try {
      final existingRequests = await FirebaseFirestore.instance
          .collection('returnRequests')
          .where('userID', isEqualTo: userId)
          .where('orderProductID', isEqualTo: orderProductId)
          .get();

      hasExistingReturnRequest = existingRequests.docs.isNotEmpty;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Load order product data (only needed when creating new return)
  Future<void> loadOrderProduct() async {
    try {
      final orderProductDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('order')
          .doc(orderId)
          .collection('orderProducts')
          .doc(orderProductId)
          .get();

      if (orderProductDoc.exists) {
        orderProduct = OrderProductModel.fromDocument(orderProductDoc);
      }

      if (orderProduct?.productID != null) {
        // Extract the document ID from the DocumentReference
        productDocumentId = orderProduct!.productID!.id;

        // Get the product document using the reference
        final productDoc = await orderProduct!.productID!.get();
        if (productDoc.exists) {
          productData = productDoc.data() as Map<String, dynamic>?;
        }
      }

      await checkExistingReturnRequest();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }


  // Load return request for status page
  Stream<DocumentSnapshot> getReturnRequestStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('returnRequests')
        .doc(existingReturnRequestId!)
        .snapshots();
  }

  // Load return request data - SIMPLIFIED!
  Future<void> loadReturnRequest(DocumentSnapshot snapshot) async {
    try {
      returnRequest = ReturnRequestModel.fromDocument(snapshot);

      // No need to load orderProduct or product data anymore!
      // All necessary data is denormalized in returnRequest

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading return request: $e');
      rethrow;
    }
  }

  // Update selected reason
  void updateSelectedReason(String? newReason) {
    if (newReason != null) {
      selectedReason = newReason;
      notifyListeners();
    }
  }

  // Pick images
  Future<void> pickImages() async {
    if (isUploadingImages) return;

    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        isUploadingImages = true;
        notifyListeners();

        selectedImages.addAll(images);

        isUploadingImages = false;
        notifyListeners();
      }
    } catch (e) {
      isUploadingImages = false;
      notifyListeners();
      rethrow;
    }
  }

  // Remove image
  void removeImage(int index) {
    selectedImages.removeAt(index);
    notifyListeners();
  }

  // Upload images to Firebase Storage
  Future<List<String>> uploadImagesToStorage(List<XFile> images) async {
    try {
      final storage = FirebaseStorage.instance;
      List<String> downloadUrls = [];

      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        final fileName = 'return_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = storage.ref().child('return_images').child(fileName);

        final uploadTask = await ref.putFile(File(image.path));
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        downloadUrls.add(downloadUrl);
      }

      return downloadUrls;
    } catch (e) {
      throw Exception('Failed to upload images: $e');
    }
  }

  // Validate form
  bool validateForm() {
    return descriptionController.text.trim().isNotEmpty;
  }

  // Submit return request with denormalized data
  // Submit return request with denormalized data
  Future<void> submitRequest() async {
    if (!validateForm()) {
      throw Exception('Please provide a description');
    }

    isSubmitting = true;
    notifyListeners();

    try {
      // Upload images first
      List<String> uploadedUrls = [];
      if (selectedImages.isNotEmpty) {
        uploadedUrls = await uploadImagesToStorage(selectedImages);
      }

      final double returnPrice = orderProduct?.totalPrice ?? 0.0;
      final int returnQuantity = orderProduct?.productQuantity ?? 1;
      final String productName = productData?['productName'] ?? 'Unknown Product';

      // Use the document ID as productID instead of getting it from productData
      final String productID = productDocumentId ?? 'Unknown Product ID';

      final productURLList = productData?['productURL'];
      final String productImageUrl = (productURLList is List && productURLList.isNotEmpty)
          ? productURLList.first.toString()
          : '';

      // Create return request with denormalized data and new date fields
      final returnRequest = ReturnRequestModel(
        id: '', // Firestore will assign this
        userID: userId,
        orderID: orderId,
        orderProductID: orderProductId,
        returnDate: Timestamp.now(),
        returnImages: uploadedUrls,
        returnReason: selectedReason,
        returnStatus: 'pending_approval',
        returnComment: descriptionController.text,
        rejectReason: null, // Only set when rejected
        returnPrice: returnPrice,
        returnQuantity: returnQuantity,        // Denormalized
        productID: productID,                  // Now uses document ID
        productName: productName,              // Denormalized
        productImageUrl: productImageUrl,      // Denormalized

        // New date fields - initially null, will be set when status changes
        pendingDate: Timestamp.now(),
        approvedDate: null,
        rejectedDate: null,
        completedDate: null,
        pendinginspectionDate: null,
        completedinsepectionDate: null,
        cancelledDate: null,
        refundID: null,
      );

      debugPrint('🚀 [SUBMIT] About to create return request...');
      debugPrint('📄 [DATA] orderId: $orderId, userId: $userId, productID: $productID');

      final docRef = await FirebaseFirestore.instance
          .collection('returnRequests')
          .add(returnRequest.toMap());

      debugPrint('✅ [SUCCESS] Return request created with ID: ${docRef.id}');

      // 🔔 Create notification for new request with ALL required parameters
      debugPrint('🔔 [SUBMIT] Creating notification...');
      try {
        await NotificationController.createReturnNotification(
          returnId: docRef.id,
          newStatus: returnRequest.returnStatus,
          userId: userId,
          productId: productID,
          orderId: orderId, // ✅ ADD THIS MISSING PARAMETER
        );
        debugPrint('✅ [NOTIFICATION] User-side notification created successfully');
      } catch (notificationError) {
        debugPrint('❌ [NOTIFICATION] User-side notification failed: $notificationError');
        // Don't throw - let the return request succeed even if notification fails
      }

    } catch (e) {
      debugPrint('❌ [SUBMIT] Submit request failed: $e');
      rethrow;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  int getCurrentStep(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
      case 'request_submitted':
        return 0;
      case 'pending':
      case 'pending_approval':
        return 1;
      case 'approved':
      case 'request_approved':
        return 2;
      case 'rejected':
        return -1; // Special case for rejected
      case 'cancelled':
        return -1; // Special case for cancelled
      default:
        return 0;
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }
}