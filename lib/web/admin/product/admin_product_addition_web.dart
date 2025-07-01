import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:html' as html;

import '../../../model/category_model.dart';
import '../widget/topbar.dart';

class ProductAdditionPage extends StatefulWidget {
  const ProductAdditionPage({Key? key}) : super(key: key);

  @override
  State<ProductAdditionPage> createState() => _ProductAdditionPageState();
}

class _ProductAdditionPageState extends State<ProductAdditionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _originalPriceController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  // Selected values
  String? selectedStatus = 'available';
  String selectedCondition = 'good';
  List<String> selectedTags = [];
  List<html.File> selectedImages = [];
  List<String> uploadedImageUrls = [];
  List<Category> categories = []; // Loaded from Firestore
  Category? selectedCategory;

  final List<String> conditions = ['good', 'like_new', 'excellent', 'fair'];
  final List<String> statuses = ['available', 'sold', 'inactive'];
  final List<String> availableTags = ['vintage', 'designer', 'limited_edition', 'rare', 'trending'];

  bool isLoading = false;
  bool isCategoriesLoading = true;

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      setState(() {
        isCategoriesLoading = true;
      });

      final snapshot = await _firestore.collection('category').get();
      setState(() {
        categories = snapshot.docs.map((doc) => Category.fromDocument(doc)).toList();
        isCategoriesLoading = false;
      });

      print('Loaded ${categories.length} categories');
      for (var cat in categories) {
        print('Category: ${cat.catName} (${cat.id})');
      }
    } catch (e) {
      print('Error loading categories: $e');
      setState(() {
        isCategoriesLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    final input = html.FileUploadInputElement()..accept = 'image/*'..multiple = true;
    input.click();

    await input.onChange.first;
    if (input.files != null) {
      setState(() {
        selectedImages = input.files!;
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> urls = [];
    for (var file in selectedImages) {
      try {
        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        await reader.onLoad.first;

        final String dataUrl = reader.result as String;
        final String base64 = dataUrl.split(',')[1];

        final ref = _storage.ref().child('products/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
        await ref.putString(base64, format: PutStringFormat.base64);
        final url = await ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        print('Error uploading image: $e');
      }
    }
    return urls;
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // Upload images first
      uploadedImageUrls = await _uploadImages();

      // Calculate discount
      final price = double.parse(_priceController.text);
      final originalPrice = _originalPriceController.text.isNotEmpty
          ? double.parse(_originalPriceController.text)
          : price;
      final discount = originalPrice > price
          ? ((originalPrice - price) / originalPrice * 100).round()
          : 0;

      // Create product document
      final productData = {
        'productName': _nameController.text,
        'description': _descriptionController.text,
        'price': price,
        'originalPrice': originalPrice,
        'discount': discount,
        'category': selectedCategory?.toMap(),
        'categoryId': selectedCategory?.id, // Also store the ID for easier queries
        'condition': selectedCondition,
        'status': selectedStatus,
        'tags': selectedTags,
        'images': uploadedImageUrls,
        'dimensions': {
          'length': _lengthController.text.isNotEmpty ? double.parse(_lengthController.text) : null,
          'width': _widthController.text.isNotEmpty ? double.parse(_widthController.text) : null,
        },
        'quantity': int.parse(_quantityController.text),
        'sku': 'SKU${DateTime.now().millisecondsSinceEpoch}',
        'addedDate': DateTime.now().millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('products').add(productData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product added successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding product: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                CustomTopBar(
                  title: 'Product',
                  subtitle: 'Add Product',
                  badgeText: 'All Shop',
                ),
                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // General Information Section
                            const Text(
                              'General Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Product Name',
                                hintText: 'Type product name here...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter product name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                hintText: 'Type product description here...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Category Section
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Category',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      isCategoriesLoading
                                          ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                          : DropdownButtonFormField<Category>(
                                        value: selectedCategory,
                                        decoration: InputDecoration(
                                          hintText: 'Select a category',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        isExpanded: true,
                                        items: categories.map((Category category) {
                                          return DropdownMenuItem<Category>(
                                            value: category,
                                            child: Text(category.catName),
                                          );
                                        }).toList(),
                                        onChanged: (Category? newValue) {
                                          setState(() {
                                            selectedCategory = newValue;
                                          });
                                          print('Selected category: ${newValue?.catName} (${newValue?.id})');
                                        },
                                        validator: (value) {
                                          if (value == null) {
                                            return 'Please select a category';
                                          }
                                          return null;
                                        },
                                        // Use catId for comparison
                                        selectedItemBuilder: (BuildContext context) {
                                          return categories.map<Widget>((Category category) {
                                            return Text(category.catName);
                                          }).toList();
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
                                      const Text(
                                        'Product Tags',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey[300]!),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Wrap(
                                          spacing: 8,
                                          children: availableTags.map((tag) {
                                            final isSelected = selectedTags.contains(tag);
                                            return FilterChip(
                                              label: Text(tag),
                                              selected: isSelected,
                                              onSelected: (selected) {
                                                setState(() {
                                                  if (selected) {
                                                    selectedTags.add(tag);
                                                  } else {
                                                    selectedTags.remove(tag);
                                                  }
                                                });
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Status Section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: selectedStatus,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  items: statuses.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedStatus = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),

                            // Media Section
                            const Text(
                              'Media',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Product Photo',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: _pickImages,
                              child: Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    style: BorderStyle.solid,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.grey),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Drag and drop image here, or click add image',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 5),
                                      ElevatedButton(
                                        onPressed: _pickImages,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF7C3AED),
                                        ),
                                        child: const Text('Add Image'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (selectedImages.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                children: selectedImages.map((file) {
                                  return Chip(
                                    label: Text(file.name),
                                    onDeleted: () {
                                      setState(() {
                                        selectedImages.remove(file);
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 30),

                            // Pricing Section
                            const Text(
                              'Pricing',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _priceController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Base Price',
                                      prefixText: '\$ ',
                                      hintText: 'Type base price here...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter price';
                                      }
                                      if (double.tryParse(value) == null) {
                                        return 'Please enter a valid number';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: TextFormField(
                                    controller: _originalPriceController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Original Price',
                                      prefixText: '\$ ',
                                      hintText: 'Type original price here...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),

                            // Inventory Section
                            const Text(
                              'Inventory',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _quantityController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Quantity',
                                      hintText: 'Type product quantity here...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter quantity';
                                      }
                                      if (int.tryParse(value) == null) {
                                        return 'Please enter a valid number';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: selectedCondition,
                                    decoration: InputDecoration(
                                      labelText: 'Condition',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    items: conditions.map((condition) {
                                      return DropdownMenuItem(
                                        value: condition,
                                        child: Text(condition),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedCondition = value!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),

                            // Shipping Section
                            const Text(
                              'Shipping',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Checkbox(
                                  value: true,
                                  onChanged: (value) {},
                                  activeColor: const Color(0xFF7C3AED),
                                ),
                                const Text('This is a physical product'),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Height', style: TextStyle(fontSize: 14)),
                                      const SizedBox(height: 5),
                                      TextFormField(
                                        controller: _lengthController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          hintText: 'Height (cm)',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
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
                                      const Text('Width', style: TextStyle(fontSize: 14)),
                                      const SizedBox(height: 5),
                                      TextFormField(
                                        controller: _widthController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          hintText: 'Width (cm)',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),

                            // Action Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey[600],
                                  ),
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: isLoading ? null : _saveProduct,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                      : const Text('Add Product'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: const Color(0xFF7C3AED),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shopping_bag, color: Color(0xFF7C3AED)),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Logo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}