import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/model/product_model.dart';
import 'package:secondsight/model/product_measurements_model.dart';
import 'package:secondsight/view/widgets/order_status_utils.dart';

import '../login/activity_logger_mixin.dart';
import 'admin_product_image.dart';
import 'measurements_widget.dart';

class ProductEditDialog extends StatefulWidget {
  final Product product;
  final Function() onUpdate;


  const ProductEditDialog({
    Key? key,
    required this.product,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<ProductEditDialog> with ActivityLoggerMixin{
  final _formKey = GlobalKey<FormState>();

  // Basic info controllers
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _oriPriceController;
  late TextEditingController _descriptionController;
  late TextEditingController _stockQuantityController;

  // Measurements controllers
  late TextEditingController _bustController;
  late TextEditingController _waistController;
  late TextEditingController _hipController;
  late TextEditingController _shoulderWidthController;
  late TextEditingController _sleeveLengthController;
  late TextEditingController _shirtLengthController;
  late TextEditingController _inseamController;
  late TextEditingController _outseamController;
  late TextEditingController _totalLengthController;

  // Virtual Try-On controllers
  late TextEditingController _tryOnDataController;
  late String _tryOnType;
  late bool _tryOnEnabled;

  // Dropdown selections
  late String _selectedCategoryId;
  late String _selectedCondition;
  late String _selectedStatus;
  late String _selectedSize;

  // Tags
  late List<String> _tags;
  final TextEditingController _tagController = TextEditingController();

  bool _isLoading = false;
  bool _categoriesLoading = true;
  List<QueryDocumentSnapshot> _categories = [];

  // Define options for dropdowns
  final List<String> _conditions = ['brand_new', 'like_new', 'good', 'used', 'well_worn'];
  final List<String> _statuses = ['available', 'sold', 'inactive'];
  final List<String> _sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL', 'Freesize', '-'];
  final List<String> _tryOnTypes = ['upper', 'lower', 'full'];

  @override
  void initState() {
    super.initState();

    // Initialize basic info controllers
    _nameController = TextEditingController(text: widget.product.name);
    _priceController = TextEditingController(text: widget.product.price.toString());
    _oriPriceController = TextEditingController(text: widget.product.oriPrice.toString());
    _descriptionController = TextEditingController(text: widget.product.description);
    _stockQuantityController = TextEditingController(text: widget.product.stockQuantity.toString());

    // Initialize measurements controllers from ProductMeasurements
    _bustController = TextEditingController(text: widget.product.measurements.bust?.toString() ?? '');
    _waistController = TextEditingController(text: widget.product.measurements.waist?.toString() ?? '');
    _hipController = TextEditingController(text: widget.product.measurements.hip?.toString() ?? '');
    _shoulderWidthController = TextEditingController(text: widget.product.measurements.shoulderWidth?.toString() ?? '');
    _sleeveLengthController = TextEditingController(text: widget.product.measurements.sleeveLength?.toString() ?? '');
    _shirtLengthController = TextEditingController(text: widget.product.measurements.shirtLength?.toString() ?? '');
    _inseamController = TextEditingController(text: widget.product.measurements.inseam?.toString() ?? '');
    _outseamController = TextEditingController(text: widget.product.measurements.outseam?.toString() ?? '');
    _totalLengthController = TextEditingController(text: widget.product.measurements.totalLength?.toString() ?? '');

    // Initialize Virtual Try-On
    _tryOnDataController = TextEditingController(text: widget.product.virtualTryOn['tryOnData'] ?? '');
    _tryOnType = widget.product.virtualTryOn['type'] ?? 'upper';
    _tryOnEnabled = widget.product.virtualTryOn['enabled'] ?? true;

    // Initialize selections
    _selectedCategoryId = widget.product.category.id;
    _selectedCondition = widget.product.condition.toLowerCase();
    _selectedStatus = widget.product.status.toLowerCase();
    _selectedSize = widget.product.productSize;

    // Initialize tags
    _tags = List<String>.from(widget.product.tags);

    // Load categories
    _loadCategories();
  }

  Future<void> _uploadTryOnImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png'], // Only allow PNG files
      allowMultiple: false,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      final bytes = file.bytes!;
      final fileName = file.name;

      // Double-check file extension (case-insensitive)
      if (!fileName.toLowerCase().endsWith('.png')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only PNG images are allowed for virtual try-on'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Validate file size (e.g., max 10MB for try-on images)
      const maxSizeInBytes = 10 * 1024 * 1024; // 10MB
      if (file.size > maxSizeInBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File size too large. Maximum 10MB allowed for PNG images'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Generate filename with PNG extension
      final uniqueFileName = 'tryon_${DateTime.now().millisecondsSinceEpoch}.png';
      final ref = FirebaseStorage.instance.ref().child('virtual_try_on/$uniqueFileName');

      // Set PNG-specific metadata
      final metadata = SettableMetadata(
        contentType: 'image/png',
        cacheControl: 'max-age=31536000', // 1 year cache
        customMetadata: {
          'originalName': fileName,
          'uploadedAt': DateTime.now().toIso8601String(),
          'fileType': 'png',
        },
      );

      try {
        // Show uploading state
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Uploading PNG image...'),
                ],
              ),
              duration: Duration(seconds: 2),
              backgroundColor: Color(0xFF7C3AED),
            ),
          );
        }

        final task = await ref.putData(bytes, metadata);
        final downloadUrl = await task.ref.getDownloadURL();

        setState(() {
          _tryOnDataController.text = downloadUrl;
          widget.product.virtualTryOn = {
            ...widget.product.virtualTryOn,
            'tryOnData': downloadUrl,
            'enabled': true,
            'type': widget.product.virtualTryOn['type'] ?? 'upper',
          };
        });

        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product.id)
            .update({
          'virtualTryOn': widget.product.virtualTryOn,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PNG try-on image uploaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('PNG upload failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload PNG image: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // User cancelled or no PNG file selected
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No PNG image selected'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('category')
          .get();

      if (mounted) {
        setState(() {
          _categories = snapshot.docs;
          _categoriesLoading = false;
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        setState(() {
          _categoriesLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _oriPriceController.dispose();
    _descriptionController.dispose();
    _stockQuantityController.dispose();
    _bustController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _shoulderWidthController.dispose();
    _sleeveLengthController.dispose();
    _shirtLengthController.dispose();
    _inseamController.dispose();
    _outseamController.dispose();
    _totalLengthController.dispose();
    _tryOnDataController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _updateProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // FIRST: Get the current product data for logging
        final productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product.id)
            .get();

        final previousData = productDoc.data() ?? {};

        // Prepare measurements data
        final measurements = ProductMeasurements(
          bust: _bustController.text.isNotEmpty ? double.parse(_bustController.text) : null,
          waist: _waistController.text.isNotEmpty ? double.parse(_waistController.text) : null,
          hip: _hipController.text.isNotEmpty ? double.parse(_hipController.text) : null,
          shoulderWidth: _shoulderWidthController.text.isNotEmpty ? double.parse(_shoulderWidthController.text) : null,
          sleeveLength: _sleeveLengthController.text.isNotEmpty ? double.parse(_sleeveLengthController.text) : null,
          shirtLength: _shirtLengthController.text.isNotEmpty ? double.parse(_shirtLengthController.text) : null,
          inseam: _inseamController.text.isNotEmpty ? double.parse(_inseamController.text) : null,
          outseam: _outseamController.text.isNotEmpty ? double.parse(_outseamController.text) : null,
          totalLength: _totalLengthController.text.isNotEmpty ? double.parse(_totalLengthController.text) : null,
        );

        // Prepare virtual try-on data
        Map<String, dynamic> virtualTryOn = {
          'tryOnData': _tryOnDataController.text.trim(),
          'type': _tryOnType,
          'enabled': _tryOnEnabled,
        };

        // Prepare the update data
        final updateData = {
          'productName': _nameController.text.trim(),
          'productPrice': double.parse(_priceController.text.trim()),
          'productOriPrice': double.parse(_oriPriceController.text.trim()),
          'productDesc': _descriptionController.text.trim(),
          'category': FirebaseFirestore.instance.collection('category').doc(_selectedCategoryId),
          'productCondition': _selectedCondition,
          'productStatus': _selectedStatus,
          'productSize': _selectedSize,
          'stockQuantity': int.parse(_stockQuantityController.text.trim()),
          'measurements': measurements.toMap(),
          'virtualTryOn': virtualTryOn,
          'tags': _tags,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Update the product
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product.id)
            .update(updateData);

        // Calculate what changed for logging
        final changes = <String, dynamic>{};

        // Check each field for changes
        if (previousData['productName'] != _nameController.text.trim()) {
          changes['productName'] = {
            'old': previousData['productName'],
            'new': _nameController.text.trim()
          };
        }

        final newPrice = double.parse(_priceController.text.trim());
        if (previousData['productPrice'] != newPrice) {
          changes['productPrice'] = {
            'old': previousData['productPrice'],
            'new': newPrice
          };
        }

        final newOriPrice = double.parse(_oriPriceController.text.trim());
        if (previousData['productOriPrice'] != newOriPrice) {
          changes['productOriPrice'] = {
            'old': previousData['productOriPrice'],
            'new': newOriPrice
          };
        }

        if (previousData['productStatus'] != _selectedStatus) {
          changes['productStatus'] = {
            'old': previousData['productStatus'],
            'new': _selectedStatus
          };
        }

        final newStock = int.parse(_stockQuantityController.text.trim());
        if (previousData['stockQuantity'] != newStock) {
          changes['stockQuantity'] = {
            'old': previousData['stockQuantity'],
            'new': newStock
          };
        }

        // LOG SUCCESSFUL UPDATE
        await logCrud(
          operation: 'update',
          targetType: 'product',
          targetId: widget.product.id,
          targetName: _nameController.text.trim(),
          changes: changes,
          previousData: previousData,
        );

        if (mounted) {
          Navigator.of(context).pop();
          widget.onUpdate();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // LOG FAILED UPDATE
        await logCrud(
          operation: 'update',
          targetType: 'product',
          targetId: widget.product.id,
          targetName: widget.product.name,
          isSuccessful: false,
          errorMessage: e.toString(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating product: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Product',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Images Preview
                      ProductImageEditor(
                        initialImages: widget.product.images,
                        onImagesChanged: (updatedImages) async {
                          // Update Firestore directly here
                          try {
                            await FirebaseFirestore.instance
                                .collection('products')
                                .doc(widget.product.id)
                                .update({
                              'productURL': updatedImages,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });

                            print('Images updated in Firestore: ${updatedImages.length}');
                          } catch (e) {
                            print('Error updating Firestore: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error saving images: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),


                      // Section: Basic Information
                      _buildSectionHeader('Basic Information'),
                      const SizedBox(height: 10),

                      // Product Name
                      _buildLabel('Product Name'),
                      TextFormField(
                        controller: _nameController,
                        decoration: _buildInputDecoration('Enter product name'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter product name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Price Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Selling Price (RM)'),
                                TextFormField(
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDecoration('0.00'),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter price';
                                    }
                                    if (double.tryParse(value.trim()) == null) {
                                      return 'Please enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Original Price (RM)'),
                                TextFormField(
                                  controller: _oriPriceController,
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDecoration('0.00'),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter original price';
                                    }
                                    if (double.tryParse(value.trim()) == null) {
                                      return 'Please enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Stock Quantity'),
                                TextFormField(
                                  controller: _stockQuantityController,
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDecoration('0'),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter stock quantity';
                                    }
                                    if (int.tryParse(value.trim()) == null) {
                                      return 'Please enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Category and Size Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Category'),
                                DropdownButtonFormField<String>(
                                  value: _categories.any((cat) => cat.id == _selectedCategoryId)
                                      ? _selectedCategoryId
                                      : null,
                                  decoration: _buildInputDecoration('Select category'),
                                  items: _categories.map((categoryDoc) {
                                    final data = categoryDoc.data() as Map<String, dynamic>;
                                    return DropdownMenuItem<String>(
                                      value: categoryDoc.id,
                                      child: Text(data['catName'] ?? data['name'] ?? 'Unknown'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedCategoryId = value!);
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a category';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Size'),
                                DropdownButtonFormField<String>(
                                  value: _sizes.contains(_selectedSize) ? _selectedSize : '-',
                                  decoration: _buildInputDecoration('Select size'),
                                  items: _sizes.map((size) {
                                    return DropdownMenuItem(
                                      value: size,
                                      child: Text(size),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedSize = value!);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Condition and Status Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Condition'),
                                DropdownButtonFormField<String>(
                                  value: _conditions.contains(_selectedCondition)
                                      ? _selectedCondition
                                      : _conditions.first,
                                  decoration: _buildInputDecoration('Select condition'),
                                  items: _conditions.map((condition) {
                                    return DropdownMenuItem(
                                      value: condition,
                                        child: Text(OrderStatusUtils.formatCondition(condition))
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedCondition = value!);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Status'),
                                DropdownButtonFormField<String>(
                                  value: _statuses.contains(_selectedStatus)
                                      ? _selectedStatus
                                      : _statuses.first,
                                  decoration: _buildInputDecoration('Select status'),
                                  items: _statuses.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(status[0].toUpperCase() + status.substring(1)),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedStatus = value!);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Description
                      _buildLabel('Description'),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _buildInputDecoration('Enter product description'),
                      ),
                      const SizedBox(height: 30),

                      // Section: Measurements
                      MeasurementsWidget(
                        selectedCategoryId: _selectedCategoryId,
                        categories: _categories,
                        bustController: _bustController,
                        waistController: _waistController,
                        hipController: _hipController,
                        shoulderWidthController: _shoulderWidthController,
                        sleeveLengthController: _sleeveLengthController,
                        shirtLengthController: _shirtLengthController,
                        inseamController: _inseamController,
                        outseamController: _outseamController,
                        totalLengthController: _totalLengthController,
                        buildLabel: _buildLabel,
                        buildInputDecoration: _buildInputDecoration,
                      ),

                      // Section: Virtual Try-On
                      // Section: Virtual Try-On
                      _buildSectionHeader('Virtual Try-On'),
                      const SizedBox(height: 10),

// Only show the Try-On Row if _tryOnEnabled is true
                      if (_tryOnEnabled)
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Try-On Image'),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: _tryOnDataController.text.isNotEmpty
                                        ? Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            _tryOnDataController.text,
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.contain,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Center(
                                                child: CircularProgressIndicator(
                                                  value: loadingProgress.expectedTotalBytes != null
                                                      ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                      : null,
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.error_outline,
                                                        size: 40,
                                                        color: Colors.red.shade400),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Failed to load image',
                                                      style: TextStyle(color: Colors.red.shade600),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        // Remove image button
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                              onPressed: () {
                                                setState(() {
                                                  _tryOnDataController.clear();
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                        : Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          style: BorderStyle.solid
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.checkroom,
                                              size: 50,
                                              color: Colors.grey.shade400),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No try-on image uploaded',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton.icon(
                                            onPressed: _uploadTryOnImage,
                                            icon: const Icon(Icons.upload),
                                            label: const Text('Upload Image'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Status indicator (no URL shown)
                                  if (_tryOnDataController.text.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Try-on image uploaded successfully',
                                            style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const Spacer(),
                                          TextButton(
                                            onPressed: _uploadTryOnImage,
                                            child: const Text('Replace'),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Try-On Type'),
                                  DropdownButtonFormField<String>(
                                    value: _tryOnType,
                                    decoration: _buildInputDecoration('Select clothing type'),
                                    items: _tryOnTypes.map((type) {
                                      return DropdownMenuItem(
                                        value: type,
                                        child: Text(type[0].toUpperCase() + type.substring(1)),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() => _tryOnType = value!);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 15),

                      CheckboxListTile(
                        title: const Text('Enable Virtual Try-On'),
                        value: _tryOnEnabled,
                        onChanged: (value) {
                          setState(() => _tryOnEnabled = value ?? true);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 30),


                      // Section: Tags
                      _buildSectionHeader('Tags'),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tagController,
                              decoration: _buildInputDecoration('Add a tag'),
                              onFieldSubmitted: (_) => _addTag(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _addTag,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                      if (_tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tags.map((tag) {
                            return Chip(
                              label: Text(tag),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () => _removeTag(tag),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Footer with Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text('Update Product'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


Widget _buildSectionHeader(String title) {
  return Text(
    title,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Color(0xFF7C3AED),
    ),
  );
}

Widget _buildLabel(String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

InputDecoration _buildInputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey[300]!),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey[300]!),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF7C3AED)),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 12,
    ),
  );
}