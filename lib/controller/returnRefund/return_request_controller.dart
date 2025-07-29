// return_request_controller.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
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

  // Data
  OrderProductModel? orderProduct;
  Map<String, dynamic>? productData;
  ReturnRequestModel? returnRequest;

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
    final productURLList = productData?['productURL'];
    return (productURLList is List && productURLList.isNotEmpty)
        ? productURLList.first.toString()
        : '';
  }

  String get productName => productData?['productName'] ?? 'Unknown Product';

  // Load order product data
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
        final orderProductData = orderProductDoc.data() as Map<String, dynamic>;
        orderProduct = OrderProductModel.fromJson(orderProductData);

        // Load product details
        if (orderProduct?.productID != null) {
          final productDoc = await orderProduct!.productID!.get();
          if (productDoc.exists) {
            productData = productDoc.data() as Map<String, dynamic>?;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading order product: $e');
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

  // Load return request data
  Future<void> loadReturnRequest(DocumentSnapshot snapshot) async {
    try {
      returnRequest = ReturnRequestModel.fromDocument(snapshot);

      // Load associated order product
      final orderProductDoc = await FirebaseFirestore.instance
          .doc(returnRequest!.orderProductID)
          .get();

      if (orderProductDoc.exists) {
        final orderProductData = orderProductDoc.data() as Map<String, dynamic>;
        orderProduct = OrderProductModel.fromJson(orderProductData);

        // Load product details
        if (orderProduct?.productID != null) {
          final productDoc = await orderProduct!.productID!.get();
          if (productDoc.exists) {
            productData = productDoc.data() as Map<String, dynamic>?;
          }
        }
      }
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

        // Note: We're not uploading immediately anymore
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

  // Submit return request
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

      // Create return request
      final returnRequest = ReturnRequestModel(
        id: '', // Firestore will assign this
        userID: userId,
        orderID: orderId,
        orderProductID: orderProductId,
        returnDate: Timestamp.now(),
        returnImages: uploadedUrls,
        returnReason: selectedReason,
        returnStatus: 'submitted',
        returnComment: descriptionController.text,
        returnPrice: returnPrice,
      );

      await FirebaseFirestore.instance
          .collection('returnRequests')
          .add(returnRequest.toMap());

    } catch (e) {
      rethrow;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  // Get progress step information
  int getCurrentStep(String status) {
    final steps = ['submitted', 'pending', 'approved'];
    int currentStep = steps.indexOf(status.toLowerCase());
    return currentStep == -1 ? 0 : currentStep;
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }
}