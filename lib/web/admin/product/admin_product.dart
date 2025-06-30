import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../model/product_model.dart';
import 'admin_product_addition.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => isLoading = true);

    try {
      final snapshot = await _firestore.collection('Product').get();

      final loadedProducts = snapshot.docs
          .map((doc) => Product.fromDocumentSnapshot(doc))
          .toList();

      print('✅ Products fetched: ${loadedProducts.length}');
      for (var product in loadedProducts) {
        print('🧾 ${product.name} | RM${product.price} | ${product.status}');
      }

      setState(() {
        products = loadedProducts;
        filteredProducts = loadedProducts;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading products: $e');
      setState(() => isLoading = false);
    }
  }



  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredProducts = products;
      } else {
        filteredProducts = products.where((product) {
          return product.name.toLowerCase().contains(query.toLowerCase()) ||
              product.id.toLowerCase().contains(query.toLowerCase()) ||
              product.condition.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
      currentPage = 1;
    });
  }


  Future<void> _deleteProduct(String productId) async {
    try {
      await _firestore.collection('Product').doc(productId).delete();
      _loadProducts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting product: $e')),
      );
    }
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
                                  onChanged: _filterProducts,
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
                                  ).then((_) => _loadProducts());
                                },
                                icon: Icon(Icons.add),
                                label: Text('Add Product'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF7C3AED),
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
                              _buildFilterTab('All Products', true),
                              SizedBox(width: 20),
                              _buildFilterTab('Published', false),
                              SizedBox(width: 20),
                              _buildFilterTab('Low Stock', false),
                              SizedBox(width: 20),
                              _buildFilterTab('Draft', false),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),

                        // Product table
                        Expanded(
                          child: isLoading
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
                                DataColumn(label: Text('Added')),
                                DataColumn(label: Text('Action')),
                              ],
                              rows: paginatedProducts.map((product) {
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
                                            child: product.images.isNotEmpty
                                                ? Image.network(product.images.first, fit: BoxFit.cover)
                                                : const Icon(Icons.image, color: Colors.grey),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(product.name),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(product.id.substring(0, 8))), // assuming SKU fallback
                                    DataCell(Text(product.category.id)), // Optional: Resolve to category name if needed
                                    DataCell(Text(product.condition)),
                                    DataCell(Text('RM${product.price.toStringAsFixed(2)}')),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(product.status).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          product.status,
                                          style: TextStyle(
                                            color: _getStatusColor(product.status),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(_formatDate(product.createdAt))),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 18),
                                            onPressed: () {
                                              // Navigate to edit page
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
                                                        _deleteProduct(product.id);
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
                          padding: EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Showing ${startIndex + 1} to ${endIndex > filteredProducts.length ? filteredProducts.length : endIndex} of ${filteredProducts.length} items'),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null,
                                    icon: Icon(Icons.chevron_left),
                                  ),
                                  ...List.generate(
                                    totalPages > 5 ? 5 : totalPages,
                                        (index) {
                                      final pageNum = index + 1;
                                      return Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: ElevatedButton(
                                          onPressed: () => setState(() => currentPage = pageNum),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: currentPage == pageNum ? Color(0xFF7C3AED) : Colors.grey[300],
                                            minimumSize: Size(40, 40),
                                          ),
                                          child: Text(
                                            '$pageNum',
                                            style: TextStyle(
                                              color: currentPage == pageNum ? Colors.white : Colors.black,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    onPressed: currentPage < totalPages ? () => setState(() => currentPage++) : null,
                                    icon: Icon(Icons.chevron_right),
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

        ],
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
          Text(
            'Product',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
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

  Widget _buildFilterTab(String title, bool isActive) {
    return Container(
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return Colors.green;
      case 'draft':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getMonth(int month) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}