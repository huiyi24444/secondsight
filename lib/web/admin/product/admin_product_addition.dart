import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:html' as html;

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
  String? selectedCategory;
  String? selectedStatus = 'Draft';
  String selectedCondition = 'Good';
  List<String> selectedTags = [];
  List<html.File> selectedImages = [];
  List<String> uploadedImageUrls = [];

  // Options
  final List<String> categories = ['Hoodies', 'Jackets', 'T-Shirts', 'Pants', 'Accessories'];
  final List<String> conditions = ['Good', 'Like New', 'Excellent', 'Fair'];
  final List<String> statuses = ['Draft', 'Published'];
  final List<String> availableTags = ['Vintage', 'Designer', 'Limited Edition', 'Rare', 'Trending'];

  bool isLoading = false;

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
        'category': selectedCategory,
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

      await _firestore.collection('Product').add(productData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product added successfully!')),
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
                _buildTopBar(),
                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
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
                        padding: EdgeInsets.all(30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // General Information Section
                            Text(
                              'General Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
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
                            SizedBox(height: 20),
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
                            SizedBox(height: 30),

                            // Category Section
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Category',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      DropdownButtonFormField<String>(
                                        value: selectedCategory,
                                        decoration: InputDecoration(
                                          hintText: 'Select a category',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        items: categories.map((category) {
                                          return DropdownMenuItem(
                                            value: category,
                                            child: Text(category),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            selectedCategory = value;
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null) {
                                            return 'Please select a category';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Product Tags',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            SizedBox(height: 20),

                            // Status Section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 10),
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
                            SizedBox(height: 30),

                            // Media Section
                            Text(
                              'Media',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Product Photo',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                            SizedBox(height: 10),
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
                                      SizedBox(height: 10),
                                      Text(
                                        'Drag and drop image here, or click add image',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                      SizedBox(height: 5),
                                      ElevatedButton(
                                        onPressed: _pickImages,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF7C3AED),
                                        ),
                                        child: Text('Add Image'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (selectedImages.isNotEmpty) ...[
                              SizedBox(height: 10),
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
                            SizedBox(height: 30),

                            // Pricing Section
                            Text(
                              'Pricing',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
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
                                SizedBox(width: 20),
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
                            SizedBox(height: 30),

                            // Inventory Section
                            Text(
                              'Inventory',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 20),
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
                                SizedBox(width: 20),
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
                            SizedBox(height: 30),

                            // Shipping Section
                            Text(
                              'Shipping',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Checkbox(
                                  value: true,
                                  onChanged: (value) {},
                                  activeColor: Color(0xFF7C3AED),
                                ),
                                Text('This is a physical product'),
                              ],
                            ),
                            SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Height', style: TextStyle(fontSize: 14)),
                                      SizedBox(height: 5),
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
                                SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Width', style: TextStyle(fontSize: 14)),
                                      SizedBox(height: 5),
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
                            SizedBox(height: 40),

                            // Action Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Cancel'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: isLoading ? null : _saveProduct,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF7C3AED),
                                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                  ),
                                  child: isLoading
                                      ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                      : Text('Add Product'),
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
      color: Color(0xFF7C3AED),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shopping_bag, color: Color(0xFF7C3AED)),
                ),
                SizedBox(width: 10),
                Text(
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
          _buildMenuItem(Icons.dashboard, 'Dashboard', false),
          _buildMenuItem(Icons.shopping_cart, 'Product Management', true),
          _buildMenuItem(Icons.list_alt, 'Order Management', false),
          _buildMenuItem(Icons.people, 'Customer Management', false),
          _buildMenuItem(Icons.report, 'Reports', false),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, bool isActive) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        onTap: () {
          // Navigation logic here
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 60,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Row(
            children: [
              Text(
                'Product',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 10),
              Icon(Icons.chevron_right),
              SizedBox(width: 10),
              Text(
                'Add Product',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'All Shop',
              style: TextStyle(color: Colors.orange[800]),
            ),
          ),
          SizedBox(width: 10),
          Icon(Icons.notifications_outlined),
          SizedBox(width: 10),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.person, color: Colors.grey[600]),
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