import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/view/widgets/product_status_utils.dart';
import 'package:secondsight/view/widgets/string_extensions.dart';

import '../../../model/product_model.dart';
import '../../../view/widgets/string_extensions.dart';
import '../services/permissions_guard.dart';
import '../services/permissions_manager.dart';
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

  String selectedSortOption = 'newest';
  String selectedCategory = 'All Categories';
  String selectedCondition = 'All Conditions';
  bool showAdvancedFilters = false;

  @override
  void initState() {
    super.initState();
    controller.loadProducts(() => setState(() {}));
    controller.loadCategories(() => setState(() {}));
  }

  void _applyAdvancedFilters() {
    List<Product> filtered = List.from(controller.allProducts);

    // Apply search filter
    if (controller.searchQuery.isNotEmpty) {
      filtered = filtered.where((product) =>
      product.name.toLowerCase().contains(controller.searchQuery.toLowerCase()) ||
          ProductStatusUtils.shortProductId(product.id).toLowerCase().contains(controller.searchQuery.toLowerCase())
      ).toList();
    }

    // Apply status filter
    if (controller.selectedStatus != 'All Products') {
      filtered = filtered.where((product) =>
      product.status.toLowerCase() == controller.selectedStatus.toLowerCase()
      ).toList();
    }

    // Apply category filter
    if (selectedCategory != 'All Categories') {
      filtered = filtered.where((product) =>
      controller.getCategoryName(product.category.id) == selectedCategory
      ).toList();
    }

    // Apply condition filter
    if (selectedCondition != 'All Conditions') {
      filtered = filtered.where((product) =>
      product.condition.toLowerCase() == selectedCondition.toLowerCase()
      ).toList();
    }

    // Apply sorting
    switch (selectedSortOption) {
      case 'newest':
        filtered.sort((a, b) => (b.createdAt?.compareTo(a.createdAt ?? Timestamp.now()) ?? 0));
        break;
      case 'oldest':
        filtered.sort((a, b) => (a.createdAt?.compareTo(b.createdAt ?? Timestamp.now()) ?? 0));
        break;
      case 'name_asc':
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'name_desc':
        filtered.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'price_low_high':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high_low':
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
    }

    // Update filtered products and reset pagination
    controller.filteredProducts = filtered;
    controller.currentPage = 1;

    // Ensure we're on a valid page
    if (controller.totalPages > 0 && controller.currentPage > controller.totalPages) {
      controller.currentPage = controller.totalPages;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {

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
                          child: Column(
                            children: [
                              // Search bar and Add button row
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        hintText: 'Search products by name or SKU...',
                                        prefixIcon: Icon(Icons.search),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey[300]!),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onChanged: (query) {
                                        controller.searchQuery = query;
                                        _applyAdvancedFilters();
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 15),
                                  // Advanced Filters Toggle Button
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        showAdvancedFilters = !showAdvancedFilters;
                                      });
                                    },
                                    icon: Icon(
                                      showAdvancedFilters ? Icons.filter_list_off : Icons.filter_list,
                                      color: showAdvancedFilters ? Color(0xFF7C3AED) : Colors.grey[600],
                                    ),
                                    tooltip: 'Advanced Filters',
                                  ),
                                  SizedBox(width: 5),
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

                              // Advanced Filters Panel
                              if (showAdvancedFilters) ...[
                                SizedBox(height: 10),
                                Container(
                                  padding: EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Advanced Filters',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Color(0xFF7C3AED),
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                selectedSortOption = 'newest';
                                                selectedCategory = 'All Categories';
                                                selectedCondition = 'All Conditions';
                                                controller.selectedStatus = 'All Products';
                                                controller.searchQuery = '';
                                                _searchController.clear();
                                              });
                                              _applyAdvancedFilters();
                                            },
                                            icon: Icon(Icons.clear, size: 16),
                                            label: Text('Clear All Filters'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 2),
                                      Row(
                                        children: [
                                          // Sort by dropdown
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Sort by',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                SizedBox(height: 5),
                                                DropdownButtonFormField<String>(
                                                  value: selectedSortOption,
                                                  decoration: InputDecoration(
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    isDense: true,
                                                  ),
                                                  items: [
                                                    DropdownMenuItem(value: 'newest', child: Text('Most Recent')),
                                                    DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                                                    DropdownMenuItem(value: 'name_asc', child: Text('Name (A-Z)')),
                                                    DropdownMenuItem(value: 'name_desc', child: Text('Name (Z-A)')),
                                                    DropdownMenuItem(value: 'price_low_high', child: Text('Price (Low to High)')),
                                                    DropdownMenuItem(value: 'price_high_low', child: Text('Price (High to Low)')),
                                                  ],
                                                  onChanged: (value) {
                                                    setState(() {
                                                      selectedSortOption = value!;
                                                    });
                                                    _applyAdvancedFilters();
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 15),

                                          // Category filter
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Category',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                SizedBox(height: 5),
                                                DropdownButtonFormField<String>(
                                                  value: selectedCategory,
                                                  decoration: InputDecoration(
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    isDense: true,
                                                  ),
                                                  items: [
                                                    DropdownMenuItem(value: 'All Categories', child: Text('All Categories')),
                                                    ...controller.categories.map((cat) {
                                                      final data = cat.data() as Map<String, dynamic>;
                                                      final catName = data['catName'] as String? ?? data['name'] as String? ?? 'Unknown';
                                                      return DropdownMenuItem(value: catName, child: Text(catName));
                                                    }),
                                                  ],
                                                  onChanged: (value) {
                                                    setState(() {
                                                      selectedCategory = value!;
                                                    });
                                                    _applyAdvancedFilters();
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 15),

                                          // Condition filter
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Condition',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                SizedBox(height: 5),
                                                DropdownButtonFormField<String>(
                                                  value: selectedCondition,
                                                  decoration: InputDecoration(
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    isDense: true,
                                                  ),
                                                  items: [
                                                    DropdownMenuItem(value: 'All Conditions', child: Text('All Conditions')),
                                                    DropdownMenuItem(value: 'new', child: Text('New')),
                                                    DropdownMenuItem(value: 'like_new', child: Text('Like New')),
                                                    DropdownMenuItem(value: 'good', child: Text('Good')),
                                                    DropdownMenuItem(value: 'fair', child: Text('Fair')),
                                                    DropdownMenuItem(value: 'poor', child: Text('Poor')),
                                                  ],
                                                  onChanged: (value) {
                                                    setState(() {
                                                      selectedCondition = value!;
                                                    });
                                                    _applyAdvancedFilters();
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Clear filters butto
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Filter tabs
                        Container(
                          padding: EdgeInsets.only(top: 1, left: 20, right: 20),
                          child: Row(
                            children: [
                              _buildFilterTab(
                                'All Products',
                                controller.selectedStatus == 'All Products',
                                    () {
                                  controller.selectedStatus = 'All Products';
                                  _applyAdvancedFilters(); // CHANGED: Use _applyAdvancedFilters
                                },
                              ),
                              SizedBox(width: 20),
                              _buildFilterTab(
                                'Available',
                                controller.selectedStatus == 'Available',
                                    () {
                                  controller.selectedStatus = 'Available';
                                  _applyAdvancedFilters(); // CHANGED: Use _applyAdvancedFilters
                                },
                              ),
                              SizedBox(width: 20),
                              _buildFilterTab(
                                'Sold',
                                controller.selectedStatus == 'Sold',
                                    () {
                                  controller.selectedStatus = 'Sold';
                                  _applyAdvancedFilters(); // CHANGED: Use _applyAdvancedFilters
                                },
                              ),
                              SizedBox(width: 20),
                              _buildFilterTab(
                                'Inactive',
                                controller.selectedStatus == 'Inactive',
                                    () {
                                  controller.selectedStatus = 'Inactive';
                                  _applyAdvancedFilters(); // CHANGED: Use _applyAdvancedFilters
                                },
                              ),

                              // Add results counter at the end
                              Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Color(0xFF7C3AED).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${controller.filteredProducts.length} results',
                                  style: TextStyle(
                                    color: Color(0xFF7C3AED),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        //SizedBox(height: 20),

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
                                DataColumn(label: Text('ID')),
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
                                          SizedBox(
                                            width: 150, // fixed column width
                                            child: Tooltip(
                                              message: product.name, // full text on hover
                                              child: Text(
                                                product.name,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                        ],

                                      ),
                                    ),

                                    DataCell(Text(ProductStatusUtils.shortProductId(product.id))),
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
                                          PermissionIconButton(
                                            icon: const Icon(Icons.edit, size: 18),
                                            requiredPermissions: [AdminPermissions.editProducts],
                                            onPressed: () {
                                              debugPrint('Edit icon pressed for product: ${product.id}');

                                              showDialog(
                                                context: context,
                                                builder: (context) {
                                                  debugPrint('Opening ProductEditDialog for product: ${product.id}');
                                                  return ProductEditDialog(
                                                    product: product,
                                                    onUpdate: () {
                                                      debugPrint('Product updated, reloading product list...');
                                                      controller.loadProducts(() {
                                                        debugPrint('Products reloaded, calling setState...');
                                                        setState(() {});
                                                      });
                                                    },
                                                  );
                                                },
                                              );
                                            },
                                            tooltip: 'Edit Product',
                                            disabledTooltip: 'You need edit permission',
                                          ),

                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Delete Product'),
                                                  content: const Text(
                                                    'Are you sure you want to delete this product? '
                                                        'Products associated with orders cannot be deleted.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () async {
                                                        Navigator.pop(context);

                                                        // Show loading indicator
                                                        showDialog(
                                                          context: context,
                                                          barrierDismissible: false,
                                                          builder: (context) => const AlertDialog(
                                                            content: Row(
                                                              children: [
                                                                CircularProgressIndicator(
                                                                  strokeWidth: 2,
                                                                  color: Color(0xFF7C3AED),
                                                                ),
                                                                SizedBox(width: 20),
                                                                Text('Checking product usage...'),
                                                              ],
                                                            ),
                                                          ),
                                                        );

                                                        // Check and delete using optimized method
                                                        await controller.deleteProduct(
                                                          product.id,
                                                              () => setState(() {}),
                                                          context: context,
                                                        );

                                                        // Close loading dialog
                                                        if (context.mounted) {
                                                          Navigator.pop(context);
                                                        }
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