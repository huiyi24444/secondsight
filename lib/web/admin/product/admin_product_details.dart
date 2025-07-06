import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/model/product_model.dart';

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

class _ProductEditDialogState extends State<ProductEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late String _selectedCategoryId;
  late String _selectedCondition;
  late String _selectedStatus;
  bool _isLoading = false;
  bool _categoriesLoading = true;

  // Categories from Firebase
  List<QueryDocumentSnapshot> _categories = [];

  // Define options for dropdowns
  final List<String> _conditions = ['new', 'like new', 'good', 'fair', 'poor'];
  final List<String> _statuses = ['available', 'sold', 'inactive'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _priceController = TextEditingController(text: widget.product.price.toString());
    _descriptionController = TextEditingController(text: widget.product.description ?? '');

    // Store the category ID from the product
    _selectedCategoryId = widget.product.category.id;

    // Normalize condition and status to lowercase to match dropdown options
    _selectedCondition = widget.product.condition.toLowerCase();
    _selectedStatus = widget.product.status.toLowerCase();

    // Load categories from Firebase
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      // Note: The collection name might be 'category' not 'categories'
      // Based on your project files, it seems to be 'category'
      final snapshot = await FirebaseFirestore.instance
          .collection('category')  // Changed from 'categories' to 'category'
          .get();

      print('Loaded ${snapshot.docs.length} categories'); // Debug log

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Update the product with the new values
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product.id)
            .update({
          'name': _nameController.text.trim(),
          'price': double.parse(_priceController.text.trim()),
          'description': _descriptionController.text.trim(),
          'category': {
            'id': _selectedCategoryId,  // Store as an object with id field
          },
          'condition': _selectedCondition,
          'status': _selectedStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
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
                      if (widget.product.images.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.product.images.length,
                            itemBuilder: (context, index) {
                              return Container(
                                margin: const EdgeInsets.only(right: 10),
                                width: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    widget.product.images[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

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

                      // Price and Category Row
                      Row(
                        children: [
                          // Price
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Price (RM)'),
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
                          // Category
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Category'),
                                _categoriesLoading
                                    ? TextFormField(
                                  enabled: false,
                                  decoration: _buildInputDecoration('Loading categories...'),
                                )
                                    : DropdownButtonFormField<String>(
                                  value: _categories.any((cat) => cat.id == _selectedCategoryId)
                                      ? _selectedCategoryId
                                      : null,
                                  decoration: _buildInputDecoration('Select category'),
                                  items: _categories.map((categoryDoc) {
                                    final data = categoryDoc.data() as Map<String, dynamic>;
                                    // Based on your project structure, the field name is 'catName'
                                    return DropdownMenuItem(
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
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Condition and Status Row
                      Row(
                        children: [
                          // Condition
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
                                      child: Text(condition.split(' ').map((word) =>
                                      word[0].toUpperCase() + word.substring(1)).join(' ')),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedCondition = value!);
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a condition';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Status
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
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a status';
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

                      // Description
                      _buildLabel('Description'),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: _buildInputDecoration('Enter product description'),
                      ),
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
}