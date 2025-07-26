import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:secondsight/web/admin/product/admin_product_addition_controller.dart';
import 'dart:html' as html;

import '../../../admin_main.dart';
import '../../../model/category_model.dart';
import '../customer/admin_customer.dart';
import '../order/admin_order.dart';
import '../returnrefund/admin_return.dart';
import '../widget/sidebar.dart';
import '../widget/topbar.dart';
import 'measurements_widget.dart';


class ProductAdditionPage extends StatefulWidget {
  const ProductAdditionPage({Key? key}) : super(key: key);

  @override
  State<ProductAdditionPage> createState() => _ProductAdditionPageState();
}


class _ProductAdditionPageState extends State<ProductAdditionPage> {
  late final ProductAdditionController controller;
  String currentPage = 'products';


  @override
  void initState() {
    super.initState();
    controller = ProductAdditionController(
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instance,
    );
    controller.loadCategories(() => setState(() {}));
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Sidebar
          AdminSidebar(
            currentPage: currentPage,
            onPageChanged: (String page) {
              // Handle navigation based on selected page
              switch (page) {
                case 'dashboard':
                // Navigate to dashboard - since we're in a sub-page, we go back to main
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => AdminNavigator()),
                        (route) => false,
                  );
                  break;
                case 'products':
                // Already on products page, might want to go back to product list
                  Navigator.pop(context);
                  break;
                case 'orders':
                // Navigate to order management
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => OrderManagementPage()),
                  );
                  break;
                case 'returns':
                // Navigate to return management
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => ReturnManagementPage()),
                  );
                  break;
                case 'customers':
                // Navigate to customer management
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => CustomerManagementPage()),
                  );
                  break;
                case 'reports':
                // Navigate to reports - you'll need to create this page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reports page not implemented yet')),
                  );
                  break;
              }
            },
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                CustomTopBar(
                  title: 'Product',
                  subtitle: 'Add Product',
                ),
                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: controller.formKey,
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
                              controller: controller.nameController,
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
                              controller: controller.descriptionController,
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
                                      controller.isCategoriesLoading
                                          ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                          : DropdownButtonFormField<Category>(
                                        value: controller.selectedCategory,
                                        decoration: InputDecoration(
                                          hintText: 'Select a category',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        isExpanded: true,
                                        items: controller.categories.map((Category category) {
                                          return DropdownMenuItem<Category>(
                                            value: category,
                                            child: Text(category.catName),
                                          );
                                        }).toList(),
                                        onChanged: (Category? newValue) {
                                          setState(() {
                                            controller.selectedCategory = newValue;
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
                                          children: controller.availableTags.map((tag) {
                                            final isSelected = controller.selectedTags.contains(tag);
                                            return FilterChip(
                                              label: Text(tag),
                                              selected: isSelected,
                                              onSelected: (selected) {
                                                setState(() {
                                                  if (selected) {
                                                    controller.selectedTags.add(tag);
                                                  } else {
                                                    controller.selectedTags.remove(tag);
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
                                  value: controller.selectedStatus,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  items: controller.statuses.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      controller.selectedStatus = value;
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
                              'Product Photos (Maximum 5 images)',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: controller.selectedImages.length < 5
                                  ? () => controller.pickImages(() => setState(() {}))
                                  : null,
                              child: Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    style: BorderStyle.solid,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: controller.selectedImages.length >= 5 ? Colors.grey[100] : Colors.white,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                          Icons.cloud_upload_outlined,
                                          size: 40,
                                          color: controller.selectedImages.length >= 5 ? Colors.grey[400] : Colors.grey
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        controller.selectedImages.length >= 5
                                            ? 'Maximum images reached (5/5)'
                                            : 'Drag and drop image here, or click add image',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 5),
                                      if (controller.selectedImages.length < 5)
                                        ElevatedButton(
                                          onPressed: () => controller.pickImages(() => setState(() {})),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF7C3AED),
                                          ),
                                          child: Text('Add Image (${controller.selectedImages.length}/5)'),
                                        ),

                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (controller.selectedImages.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: controller.selectedImages.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final file = entry.value;
                                  return Stack(
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
                                          child: Image.network(
                                            html.Url.createObjectUrlFromBlob(file),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              controller.selectedImages.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 30),

                            // Virtual Try-On Section
                            const Text(
                              'Virtual Try-On',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Checkbox(
                                  value: controller.virtualTryOnEnabled,
                                  onChanged: (value) {
                                    setState(() {
                                      controller.virtualTryOnEnabled = value ?? false;
                                    });
                                  },
                                  activeColor: const Color(0xFF7C3AED),
                                ),
                                const Text('Enable Virtual Try-On'),
                              ],
                            ),
                            if (controller.virtualTryOnEnabled) ...[
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Try-On Type',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        DropdownButtonFormField<String>(
                                          value: controller.selectedTryOnType,
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          items: controller.tryOnTypes.map((type) {
                                            return DropdownMenuItem(
                                              value: type,
                                              child: Text(type),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              controller.selectedTryOnType = value!;
                                            });
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
                                          'Try-On Image',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        InkWell(
                                          onTap: () => controller.pickVirtualTryOnImage(() => setState(() {})),
                                          child: Container(
                                            height: 100,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey[300]!,
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: controller.virtualTryOnImage != null
                                                ? Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(7),
                                                  child: Image.network(
                                                    html.Url.createObjectUrlFromBlob(controller.virtualTryOnImage!),
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        controller.virtualTryOnImage = null;
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        size: 16,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                                : Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.image_outlined, color: Colors.grey[400]),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Click to upload',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                                    controller: controller.priceController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'New Price',
                                      prefixText: '\$ ',
                                      hintText: 'Type new price here...',
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
                                    controller: controller.originalPriceController,
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
                                    controller: controller.quantityController,
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
                                    value: controller.selectedCondition,
                                    decoration: InputDecoration(
                                      labelText: 'Condition',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    items: controller.conditions.map((condition) {
                                      return DropdownMenuItem(
                                        value: condition,
                                        child: Text(condition),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        controller.selectedCondition = value!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),

                            // Measurements Section
                            const Text(
                              'Product Measurements',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            MeasurementsWidget(
                              selectedCategoryId: controller.selectedCategory?.id,
                              categories: controller.categoriesFromSnapshot, // <-- List<QueryDocumentSnapshot>
                              bustController: controller.bustController,
                              waistController: controller.waistController,
                              hipController: controller.hipController,
                              shoulderWidthController: controller.shoulderWidthController,
                              sleeveLengthController: controller.sleeveLengthController,
                              shirtLengthController: controller.shirtLengthController,
                              inseamController: controller.inseamController,
                              outseamController: controller.outseamController,
                              totalLengthController: controller.totalLengthController,
                              buildLabel: (label) => Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              buildInputDecoration: (hint) => InputDecoration(
                                hintText: hint,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),

                            const SizedBox(height: 40),

                            DropdownButtonFormField<String>(
                              value: controller.selectedSize,
                              items: ['S', 'M', 'L', 'XL'].map((size) {
                                return DropdownMenuItem(
                                  value: size,
                                  child: Text(size),
                                );
                              }).toList(),
                              onChanged: (value) {
                                controller.selectedSize = value;
                              },
                              decoration: InputDecoration(
                                labelText: 'Size',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a size';
                                }
                                return null;
                              },
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
                                  onPressed: controller.isLoading
                                      ? null
                                      : () => controller.saveProduct(context, () => setState(() {})),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                  ),
                                  child: controller.isLoading
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

}