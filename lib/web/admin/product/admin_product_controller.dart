import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../model/product_model.dart';

class ProductManagementController {


  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final TextEditingController searchController = TextEditingController();

  String selectedStatus = 'All Products';
  String searchQuery = '';

  List<Product> products = [];
  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  int currentPage = 1;
  final int itemsPerPage = 10;
  bool isLoading = true;

  int get totalPages => (filteredProducts.length / itemsPerPage).ceil();
  int get startIndex => (currentPage - 1) * itemsPerPage;
  int get endIndex => startIndex + itemsPerPage;

  List<QueryDocumentSnapshot> categories = [];
  Map<String, String> categoryNames = {};
  bool categoriesLoading = true;

  Future<void> loadProducts(VoidCallback onUpdate) async {
    print('🔄 Loading products...');
    isLoading = true;
    onUpdate();

    try {
      final snapshot = await FirebaseFirestore.instance.collection('products').get();
      print('📄 Fetched ${snapshot.docs.length} products');

      allProducts = snapshot.docs.map((doc) {
        try {
          final product = Product.fromDocumentSnapshot(doc);
          return product;
        } catch (e) {
          print('❌ Error parsing product: $e');
          return null;
        }
      }).whereType<Product>().toList();


      filterProducts(() {
        isLoading = false;
        onUpdate();
      });
    } catch (e) {
      print('❌ Error fetching products from Firestore: $e');
      isLoading = false;
      onUpdate();
    }
  }



  void filterProducts(VoidCallback onUpdate) {
    filteredProducts = allProducts.where((product) {
      final matchesStatus = selectedStatus.toLowerCase() == 'all products' ||
          product.status.toLowerCase() == selectedStatus.toLowerCase();

      final matchesQuery = searchQuery.isEmpty ||
          product.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          product.id.toLowerCase().contains(searchQuery.toLowerCase());

      return matchesStatus && matchesQuery;
    }).toList();

    currentPage = 1;
    onUpdate();
  }

  Future<void> deleteProduct(String productId, VoidCallback onUpdate) async {
    try {
      await firestore.collection('products').doc(productId).delete();
      await loadProducts(onUpdate);
    } catch (e) {
      print('❌ Error deleting product: $e');
    }
  }

  List<Product> get paginatedProducts {
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;
    return filteredProducts.sublist(
      startIndex,
      endIndex > filteredProducts.length ? filteredProducts.length : endIndex,
    );
  }

  // Load categories
  Future<void> loadCategories(Function callback) async {
    try {
      categoriesLoading = true;
      callback();

      final snapshot = await firestore
          .collection('category')  // Using 'category' based on your Firebase structure
          .get();

      categories = snapshot.docs;

      // Create a map for quick category name lookups
      categoryNames = Map.fromEntries(
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return MapEntry(
                doc.id,
                data['catName'] as String? ?? data['name'] as String? ?? 'Unknown'
            );
          })
      );

      categoriesLoading = false;
      callback();

      print('Loaded ${categories.length} categories');
    } catch (e) {
      print('Error loading categories: $e');
      categoriesLoading = false;
      callback();
    }
  }

  // Get category name by ID
  String getCategoryName(String categoryId) {
    return categoryNames[categoryId] ?? 'Unknown';
  }


}
