// return_request_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../model/return_request_model.dart';
import '../../model/order_product_model.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/return_policy_prompt.dart';

class ReturnRequestView extends StatefulWidget {
  final String orderId;
  final String userId;
  final String orderProductId;
  final String? existingReturnRequestId; // If viewing existing request

  const ReturnRequestView({
    super.key,
    required this.orderId,
    required this.userId,
    required this.orderProductId,
    this.existingReturnRequestId,
  });

  @override
  State<ReturnRequestView> createState() => _ReturnRequestViewState();
}

class _ReturnRequestViewState extends State<ReturnRequestView> {
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String selectedReason = 'Item Defect';
  List<XFile> selectedImages = [];
  List<String> uploadedImageUrls = [];
  bool isSubmitting = false;
  bool isUploadingImages = false;

  final List<String> returnReasons = [
    'Item Defect',
    'Wrong Size',
    'Not as Described',
    'Damaged During Shipping',
    'Changed Mind',
    'Poor Quality',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    // If viewing existing request, show status page
    if (widget.existingReturnRequestId != null) {
      return _buildStatusPage();
    }

    // Otherwise show the request form
    return _buildRequestForm();
  }

  Widget _buildRequestForm() {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text(
          'Return & Refund',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('order')
            .doc(widget.orderId)
            .collection('orderProducts')
            .doc(widget.orderProductId)
            .get(),
        builder: (context, orderProductSnapshot) {
          if (!orderProductSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF8E6CEF),
              ),
            );
          }

          final orderProductData = orderProductSnapshot.data!.data() as Map<String, dynamic>;
          final orderProduct = OrderProductModel.fromJson(orderProductData);

          return FutureBuilder<DocumentSnapshot>(
            future: orderProduct.productID?.get(),
            builder: (context, productSnapshot) {
              if (!productSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF8E6CEF),
                  ),
                );
              }

              final product = productSnapshot.data!.data() as Map<String, dynamic>?;
              final productURLList = product?['productURL'];
              final productURL = (productURLList is List && productURLList.isNotEmpty)
                  ? productURLList.first.toString()
                  : '';
              final productName = product?['productName'] ?? 'Unknown Product';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.network(
                                productURL,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  productName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Quantity: x${orderProduct.productQuantity}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'RM ${orderProduct.totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8E6CEF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Reason for Refund
                    const Text(
                      'Reason for Refund',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedReason,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down),
                          items: returnReasons.map((String reason) {
                            return DropdownMenuItem<String>(
                              value: reason,
                              child: Text(reason),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedReason = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Short Description
                    const Text(
                      'Short Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Describe the issue in detail...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Add Images Section
                    const Text(
                      'Add Images (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Image selection area
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 40,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isUploadingImages
                                  ? 'Uploading images...'
                                  : 'Tap to upload images',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (isUploadingImages)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF8E6CEF),
                                ),
                              )
                            else
                              ElevatedButton(
                                onPressed: _pickImages,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8E6CEF).withOpacity(0.1),
                                  foregroundColor: const Color(0xFF8E6CEF),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Choose Images'),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Selected Images Preview
                    if (selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: selectedImages.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: Image.file(
                                        File(selectedImages[index].path),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedImages.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Submit Button - Pass orderProduct to _submitRequest
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : () => _submitRequest(orderProduct),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8E6CEF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text(
          'Return & Refund',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('returnRequests')
            .doc(widget.existingReturnRequestId)
            .snapshots(),
        builder: (context, returnSnapshot) {
          if (!returnSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF8E6CEF),
              ),
            );
          }

          final returnRequest = ReturnRequestModel.fromDocument(returnSnapshot.data!);

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .doc(returnRequest.orderProductID)
                .get(),
            builder: (context, orderProductSnapshot) {
              if (!orderProductSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF8E6CEF),
                  ),
                );
              }

              final orderProductData = orderProductSnapshot.data!.data() as Map<String, dynamic>;
              final orderProduct = OrderProductModel.fromJson(orderProductData);

              return FutureBuilder<DocumentSnapshot>(
                future: orderProduct.productID?.get(),
                builder: (context, productSnapshot) {
                  if (!productSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8E6CEF),
                      ),
                    );
                  }

                  final product = productSnapshot.data!.data() as Map<String, dynamic>?;
                  final productURLList = product?['productURL'];
                  final productURL = (productURLList is List && productURLList.isNotEmpty)
                      ? productURLList.first.toString()
                      : '';
                  final productName = product?['productName'] ?? 'Unknown Product';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Progress Indicator
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _buildProgressIndicator(returnRequest.returnStatus),
                        ),

                        const SizedBox(height: 24),

                        // Product Details Section
                        const Text(
                          'Product Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: Image.network(
                                        productURL,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          productName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Quantity: x${orderProduct.productQuantity}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Divider(color: Colors.grey[200]),
                              const SizedBox(height: 16),

                              // Return Details - Updated to handle double returnPrice
                              _buildDetailRow('Refund Amount', 'RM ${returnRequest.returnPrice.toStringAsFixed(2)}'),
                              _buildDetailRow('Refund Reason', returnRequest.returnReason),
                              _buildDetailRow('Refund To', 'Original Payment Method'),
                              _buildDetailRow('Request ID', returnRequest.id.substring(0, 12).toUpperCase()),

                              const SizedBox(height: 16),

                              // Description
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Short Description',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Text(
                                  returnRequest.returnComment.isNotEmpty
                                      ? returnRequest.returnComment
                                      : 'Return request submitted for ${returnRequest.returnReason.toLowerCase()}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),

                              // Show reject reason if status is rejected
                              if (returnRequest.returnStatus.toLowerCase() == 'rejected' &&
                                  returnRequest.rejectReason != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red[200]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Rejection Reason',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        returnRequest.rejectReason!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.red[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Show uploaded images if any
                              if (returnRequest.returnImages.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Uploaded Images',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: returnRequest.returnImages.length,
                                    itemBuilder: (context, index) {
                                      final imageUrl = returnRequest.returnImages[index];
                                      return Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey[300]!),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(7),
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )

                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator(String currentStatus) {
    final steps = ['submitted', 'pending', 'approved'];
    final stepLabels = ['Request\nSubmitted', 'Pending\nApproval', 'Request\nApproved'];

    int currentStep = steps.indexOf(currentStatus.toLowerCase());
    if (currentStep == -1) currentStep = 0;

    return Column(
      children: [
        Row(
          children: List.generate(steps.length, (index) {
            final isCompleted = index <= currentStep;
            final isLast = index == steps.length - 1;

            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCompleted ? const Color(0xFF8E6CEF) : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: isCompleted
                        ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isCompleted ? const Color(0xFF8E6CEF) : Colors.grey[300],
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(stepLabels.length, (index) {
            final isCompleted = index <= currentStep;
            return Expanded(
              child: Text(
                stepLabels[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isCompleted ? const Color(0xFF8E6CEF) : Colors.grey[600],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    if (isUploadingImages) return;

    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          isUploadingImages = true;
        });

        // Upload images to Firebase Storage
        await _uploadImagesToStorage(images);

        setState(() {
          selectedImages.addAll(images);
          isUploadingImages = false;
        });
      }
    } catch (e) {
      setState(() {
        isUploadingImages = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<String>> _uploadImagesToStorage(List<XFile> images) async {
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

  Future<void> _submitRequest(OrderProductModel orderProduct) async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a description'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await _showReturnPolicyConfirmation();
    if (confirmed != true) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      // Upload images first
      List<String> uploadedUrls = await _uploadImagesToStorage(selectedImages);

      final double returnPrice = orderProduct.totalPrice;

      // Create return request using string values for IDs
      final returnRequest = ReturnRequestModel(
        id: '', // Firestore will assign this
        userID: widget.userId,
        orderID: widget.orderId,
        orderProductID: widget.orderProductId, // now a String
        returnDate: Timestamp.now(),
        returnImages: uploadedUrls,
        returnReason: selectedReason,
        returnStatus: 'submitted',
        returnComment: _descriptionController.text,
        returnPrice: returnPrice,
      );

      await FirebaseFirestore.instance
          .collection('returnRequests')
          .add(returnRequest.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return request submitted successfully'),
            backgroundColor: Color(0xFF8E6CEF),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }


  Future<bool?> _showReturnPolicyConfirmation() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ReturnPolicyDialog(),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}