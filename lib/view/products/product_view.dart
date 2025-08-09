import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/model/product_model.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:secondsight/view/widgets/custom_back_button.dart';
import 'package:secondsight/view/widgets/product_card.dart';

class ProductView extends StatefulWidget {
  final DocumentReference? categoryRef;
  final bool isNewIn;
  final bool isRecommendations;
  final String? userId; // Add this to pass the userId

  const ProductView({
    Key? key,
    this.categoryRef,
    this.isNewIn = false,
    this.isRecommendations = false,
    this.userId,
  }) : super(key: key);

  @override
  State<ProductView> createState() => _ProductViewState();
}

class _ProductViewState extends State<ProductView> {
  late Future<List<Product>> _recommendedProductsFuture;
  late Stream<QuerySnapshot> _productStream;

  @override
  void initState() {
    super.initState();

    if (widget.isRecommendations && widget.userId != null) {
      _recommendedProductsFuture = _fetchRankedRecommendedProducts(widget.userId!);
    } else {
      if (widget.isNewIn) {
        _productStream = FirebaseFirestore.instance
            .collection('products')
            .where('productStatus', whereNotIn: ['sold', 'inactive'])
            .where('stockQuantity', isGreaterThan: 0)
            .orderBy('createdAt', descending: true)
            .snapshots();
      } else if (widget.categoryRef != null) {
        _productStream = FirebaseFirestore.instance
            .collection('products')
            .where('category', isEqualTo: widget.categoryRef)
            .where('productStatus', whereNotIn: ['sold', 'inactive'])
            .where('stockQuantity', isGreaterThan: 0)
            .snapshots();
      } else {
        _productStream = FirebaseFirestore.instance
            .collection('products')
            .where('productStatus', whereNotIn: ['sold', 'inactive'])
            .where('stockQuantity', isGreaterThan: 0)
            .snapshots();
      }

    }
  }

  Future<List<Product>> _fetchRankedRecommendedProducts(String userId) async {
    final recommendationDocs = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recommendations')
        .orderBy('rank')
        .limit(20)
        .get();

    final rankedProductIds = recommendationDocs.docs
        .map((doc) => doc.data()['productId'] as String?)
        .where((id) => id != null && id!.isNotEmpty)
        .map((id) => id!)
        .toList();

    if (rankedProductIds.isEmpty) return [];

    final productDocs = await FirebaseFirestore.instance
        .collection('products')
        .where(FieldPath.documentId, whereIn: rankedProductIds)
        .get();

    final productMap = {
      for (var doc in productDocs.docs)
        doc.id: Product.fromDocument(doc.data() as Map<String, dynamic>, doc.id)

    };
    final filteredMap = Map.fromEntries(productMap.entries.where((entry) {
      final p = entry.value;
      return (p.status != 'sold' && p.status != 'inactive' && p.stockQuantity > 0);
    }));

    return rankedProductIds
        .where((id) => filteredMap.containsKey(id))
        .map((id) => filteredMap[id]!)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: const CustomBackButton(),
        surfaceTintColor: Colors.transparent,

      ),
      body: Padding(
        padding: const EdgeInsets.only(
          top: 0.0,
          left: 14.0,
          right: 14.0,
          bottom: 14.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titles
            if (widget.isRecommendations)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Recommended for You',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else if (widget.isNewIn)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'New In',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else if (widget.categoryRef != null)
                FutureBuilder<DocumentSnapshot>(
                  future: widget.categoryRef!.get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Category'),
                      );
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final categoryName = data['catName'] ?? 'Category';

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        categoryName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),

            // Product Grid
            Expanded(
              child: widget.isRecommendations
                  ? FutureBuilder<List<Product>>(
                future: _recommendedProductsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final products = snapshot.data!;
                  if (products.isEmpty) {
                    return const Center(
                      child: Text(
                        'No recommended products found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.60,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCard(
                        key: ValueKey(product.id),
                        product: product,
                      );
                    },
                  );
                },
              )
                  : StreamBuilder<QuerySnapshot>(
                stream: _productStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No products found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.60,
                      mainAxisSpacing: 1,
                      crossAxisSpacing: 6,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final product = Product.fromDocument(data, doc.id);
                      return ProductCard(
                        key: ValueKey(product.id),
                        product: product,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
