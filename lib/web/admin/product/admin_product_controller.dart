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

  Future<void> loadProducts(VoidCallback onUpdate) async {
    isLoading = true;
    onUpdate();

    final snapshot = await FirebaseFirestore.instance.collection('products').get();
    allProducts = snapshot.docs
        .map((doc) => Product.fromDocumentSnapshot(doc))
        .toList();

    filterProducts(() {
      isLoading = false; // ✅ turn off loading once filtering is done
      onUpdate();
    });
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

}
