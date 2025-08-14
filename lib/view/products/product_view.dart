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
  final bool isVirtualTryOn;
  final String? userId; // Add this to pass the userId

  const ProductView({
    Key? key,
    this.categoryRef,
    this.isNewIn = false,
    this.isRecommendations = false,
    this.isVirtualTryOn = false,
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

    if (widget.isRecommendations) {
      // Always initialize _recommendedProductsFuture for recommendations, regardless of userId
      _recommendedProductsFuture = _fetchRankedRecommendedProducts(widget.userId);
    } else {
      if (widget.isVirtualTryOn) {
        // New stream for Virtual Try-On products
        _productStream = FirebaseFirestore.instance
            .collection('products')
            .where('virtualTryOn.enabled', isEqualTo: true)
            .where('productStatus', whereNotIn: ['sold', 'inactive'])
            .where('stockQuantity', isGreaterThan: 0)
            .orderBy('createdAt', descending: true)
            .snapshots();
      } else if (widget.isNewIn) {
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

  Future<List<Product>> _fetchRankedRecommendedProducts(String? userId) async {
    try {
      // If user is not logged in, go directly to viewCount ranking
      if (userId == null || userId.isEmpty) {
        print('User not logged in, showing products by viewCount');
        return await _getPopularProducts();
      }

      // For logged-in users, try to get personalized recommendations first
      final recommendationDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recommendations')
          .orderBy('rank')
          .get();

      final rankedProductIds = recommendationDocs.docs
          .map((doc) => doc.data()['productId'] as String?)
          .where((id) => id != null && id!.isNotEmpty)
          .map((id) => id!)
          .toList();

      List<Product> recommendedProducts = [];

      if (rankedProductIds.isNotEmpty) {
        print('Found ${rankedProductIds.length} personalized recommendations');

        // Fetch products in batches (Firestore 'whereIn' has a limit of 10 items)
        for (int i = 0; i < rankedProductIds.length; i += 10) {
          final batch = rankedProductIds.skip(i).take(10).toList();

          final productDocs = await FirebaseFirestore.instance
              .collection('products')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          final productMap = {
            for (var doc in productDocs.docs)
              doc.id: Product.fromDocument(doc.data() as Map<String, dynamic>, doc.id)
          };

          // Filter out sold/inactive products and maintain order
          final batchProducts = batch
              .where((id) => productMap.containsKey(id))
              .map((id) => productMap[id]!)
              .where((p) => p.status != 'sold' && p.status != 'inactive' && p.stockQuantity > 0)
              .toList();

          recommendedProducts.addAll(batchProducts);
        }
      }

      // If no personalized recommendations found, fallback to products ordered by viewCount
      if (recommendedProducts.isEmpty) {
        print('No personalized recommendations found for user $userId, falling back to viewCount ranking');
        recommendedProducts = await _getPopularProducts();
      }

      return recommendedProducts;

    } catch (e) {
      print('Error fetching recommendations: $e');
      // If there's any error, fallback to viewCount ranking
      return await _getPopularProducts();
    }
  }

  Future<List<Product>> _getPopularProducts() async {
    try {
      // Try to get products ordered by viewCount first
      var productDocs = await FirebaseFirestore.instance
          .collection('products')
          .where('productStatus', whereNotIn: ['sold', 'inactive'])
          .where('stockQuantity', isGreaterThan: 0)
          .orderBy('viewCount', descending: true)
          .get();

      if (productDocs.docs.isNotEmpty) {
        print('Found ${productDocs.docs.length} products ordered by viewCount');
        return productDocs.docs
            .map((doc) => Product.fromDocument(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      }

      // If no products with viewCount, fallback to recent products
      print('No products with viewCount found, falling back to recent products');
      productDocs = await FirebaseFirestore.instance
          .collection('products')
          .where('productStatus', whereNotIn: ['sold', 'inactive'])
          .where('stockQuantity', isGreaterThan: 0)
          .orderBy('createdAt', descending: true)
          .get();

      if (productDocs.docs.isNotEmpty) {
        return productDocs.docs
            .map((doc) => Product.fromDocument(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      }

      // Last resort: get any active products
      print('No recent products found, getting any available products');
      productDocs = await FirebaseFirestore.instance
          .collection('products')
          .where('productStatus', whereNotIn: ['sold', 'inactive'])
          .where('stockQuantity', isGreaterThan: 0)
          .get();

      return productDocs.docs
          .map((doc) => Product.fromDocument(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

    } catch (e) {
      print('Error loading popular products: $e');
      return [];
    }
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  widget.userId != null ? 'Recommended for You' : 'Popular Products',
                  style: const TextStyle(
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
            else if (widget.isVirtualTryOn)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Products w/ Virtual Try On',
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    print('Error in FutureBuilder: ${snapshot.error}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Error loading products',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Please try again later',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final products = snapshot.data ?? [];
                  if (products.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No products available',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Check back later for new products',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  print('Displaying ${products.length} products in ProductView');
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Error loading products',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
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