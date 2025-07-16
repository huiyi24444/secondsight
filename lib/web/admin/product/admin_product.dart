import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/view/widgets/product_status_utils.dart';
import 'package:secondsight/view/widgets/string_extensions.dart';

import '../../../model/product_model.dart';
import '../../../view/widgets/string_extensions.dart';
import '../widget/topbar.dart';
import 'admin_product_addition.dart';
import 'admin_product_controller.dart';
import 'admin_product_details.dart';
import '../../../view/widgets/order_status_utils.dart';

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({Key? key}) : super(key: key);

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  List<Product> products = [];
  List<Product> filteredProducts = [];
  bool isLoading = true;
  int currentPage = 1;
  int itemsPerPage = 10;



  final controller = ProductManagementController();

  @override
  void initState() {
    super.initState();
    controller.loadProducts(() => setState(() {}));
    controller.loadCategories(() => setState(() {}));
  }



  @override
  Widget build(BuildContext context) {
    List<Product> paginatedProducts = filteredProducts
        .skip((currentPage - 1) * itemsPerPage)
        .take(itemsPerPage)
        .toList();

    final totalPages = (filteredProducts.length / itemsPerPage).ceil();
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;
    final currentProducts = filteredProducts.sublist(
      startIndex,
      endIndex > filteredProducts.length ? filteredProducts.length : endIndex,
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                const CustomTopBar(
                  title: 'Product',
                ),
                // Content Area
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(20),
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
                    child: Column(
                      children: [
                        // Header with search and add button
                        Container(
                          padding: EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search products...',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onChanged: (query) {
                                    controller.searchQuery = query;
                                    controller.filterProducts(() => setState(() {}));
                                  },


                                ),
                              ),
                              SizedBox(width: 20),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductAdditionPage(),
                                    ),
                                  ).then((_) => controller.loadProducts(() => setState(() {})));

                                },
                                icon: Icon(Icons.add),
                                label: Text('Add Product'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF7C3AED),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Filter tabs
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              _buildFilterTab(
                                'All Products',
                                controller.selectedStatus == 'All Products',
                                    () {
                                  controller.selectedStatus = 'All Products';
                                  controller.filterProducts(() => setState(() {}));
                                },
                              ),
                              SizedBox(width: 20),
                              _buildFilterTab(
                                'Available',
                                controller.selectedStatus == 'Available',
                                    () {
                                  controller.selectedStatus = 'Available';
                                  controller.filterProducts(() => setState(() {}));
                                },
                              ),
                              SizedBox(width: 20),
                              _buildFilterTab(
                                'Sold',
                                controller.selectedStatus == 'Sold',
                                    () {
                                  controller.selectedStatus = 'Sold';
                                  controller.filterProducts(() => setState(() {}));
                                },
                              ),
                              SizedBox(width: 20),
                              _buildFilterTab(
                                'Inactive',
                                controller.selectedStatus == 'Inactive',
                                    () {
                                  controller.selectedStatus = 'Inactive';
                                  controller.filterProducts(() => setState(() {}));
                                },
                              ),
                            ],

                          ),
                        ),
                        SizedBox(height: 20),

                        // Product table
                        Expanded(
                          child: controller.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: SizedBox(width: 30, child: Checkbox(value: false, onChanged: null))),
                                DataColumn(label: Text('Product')),
                                DataColumn(label: Text('SKU')),
                                DataColumn(label: Text('Category')),
                                DataColumn(label: Text('Condition')),
                                DataColumn(label: Text('Price')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Qty')),
                                DataColumn(label: Text('Added')),
                                DataColumn(label: Text('Action')),
                              ],
                              rows: controller.paginatedProducts.map((product) {
                                return DataRow(
                                  cells: [
                                    DataCell(Checkbox(value: false, onChanged: (v) {})),
                                    DataCell(
                                      Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[300],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: (product.images.isEmpty || product.images.first.isEmpty)
                                                ? const Icon(Icons.broken_image, color: Colors.grey, size: 24)
                                                : ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                product.images.first,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.broken_image, color: Colors.grey, size: 24),
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return Center(
                                                    child: SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Flexible(child: Text(product.name)),
                                        ],

                                      ),
                                    ),

                                    DataCell(Text(product.id.substring(0, 8).toUpperCase())),
                                    DataCell(
                                      Text(controller.getCategoryName(product.category.id)),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: OrderStatusUtils.getConditionColor(product.condition).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          OrderStatusUtils.formatCondition(product.condition),
                                          style: TextStyle(
                                            color: OrderStatusUtils.getConditionColor(product.condition),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),


                                    DataCell(Text('RM${product.price.toStringAsFixed(2)}')),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: ProductStatusUtils.getProductStatusColor(product.status).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          product.status.capitalize(),
                                          style: TextStyle(
                                            color: ProductStatusUtils.getProductStatusColor(product.status),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(product.stockQuantity.toString())),
                                    DataCell(Text(_formatDate(product.createdAt))),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 18),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => ProductEditDialog(
                                                  product: product,
                                                  onUpdate: () {
                                                    // Reload products after successful update
                                                    controller.loadProducts(() => setState(() {}));
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Delete Product'),
                                                  content: const Text('Are you sure you want to delete this product?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                        controller.deleteProduct(product.id, () => setState(() {}));
                                                      },
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                      child: const Text('Delete'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),


                        // Pagination widget remains the same
                        // Pagination
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing ${controller.startIndex + 1} to '
                                    '${controller.endIndex > controller.filteredProducts.length ? controller.filteredProducts.length : controller.endIndex} '
                                    'of ${controller.filteredProducts.length} items',
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: controller.currentPage > 1
                                        ? () => setState(() => controller.currentPage--)
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  ...List.generate(
                                    controller.totalPages > 5 ? 5 : controller.totalPages,
                                        (index) {
                                      final pageNum = index + 1;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: ElevatedButton(
                                          onPressed: () => setState(() => controller.currentPage = pageNum),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: controller.currentPage == pageNum
                                                ? const Color(0xFF7C3AED)
                                                : Colors.grey[300],
                                            minimumSize: const Size(40, 40),
                                          ),
                                          child: Text(
                                            '$pageNum',
                                            style: TextStyle(
                                              color: controller.currentPage == pageNum ? Colors.white : Colors.black,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    onPressed: controller.currentPage < controller.totalPages
                                        ? () => setState(() => controller.currentPage++)
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),


                      ],
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

  Widget _buildFilterTab(String title, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? Color(0xFF7C3AED) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Color(0xFF7C3AED) : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }


  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }



}