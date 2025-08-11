import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secondsight/model/product_model.dart';
import 'package:secondsight/view/widgets/product_card.dart';
import 'package:secondsight/view/widgets/product_small_card.dart';

class RecommendationsSection extends StatefulWidget {
  final String? userId;
  final bool showDebugInfo; // Add this parameter to control debug visibility

  const RecommendationsSection({
    Key? key,
    this.userId,
    this.showDebugInfo = true, // Default to false in production
  }) : super(key: key);

  @override
  State<RecommendationsSection> createState() => _RecommendationsSectionState();
}

class _RecommendationsSectionState extends State<RecommendationsSection> {
  Future<QuerySnapshot>? _productSnapshotsFuture;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.userId;
  }

  Future<List<Product>> _getRecommendedProducts() async {
    try {
      // CASE 1: No logged-in user -> directly return popular products
      if (widget.userId == null || widget.userId!.isEmpty) {
        print('No user logged in, fetching popular products');
        return _getPopularProducts();
      }

      // CASE 2: Try to get personalized recommendations
      final rankedIdsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('recommendations')
          .orderBy('rank')
          .limit(20)
          .get();

      final rankedProductIds = rankedIdsSnapshot.docs
          .map((doc) => doc.data()['productId'] as String?)
          .where((id) => id != null && id!.isNotEmpty)
          .map((id) => id!)
          .toList();

      // CASE 3: If no recommendations, fallback to popular products
      if (rankedProductIds.isEmpty) {
        print('No recommendations found for user ${widget.userId}, falling back to popular products');
        return _getPopularProducts();
      }

      // Fetch products by ID in order
      final productSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where(FieldPath.documentId, whereIn: rankedProductIds)
          .get();

      final productMap = {
        for (var doc in productSnapshot.docs)
          doc.id: Product.fromDocument(doc.data(), doc.id),
      };

      final recommendedProducts = rankedProductIds
          .where((id) => productMap.containsKey(id))
          .map((id) => productMap[id]!)
          .toList();

      // If recommended products are empty or insufficient, supplement with popular products
      if (recommendedProducts.length < 5) {
        print('Only ${recommendedProducts.length} recommended products found, supplementing with popular products');
        final popularProducts = await _getPopularProducts();
        final combinedProducts = <Product>[];

        // Add recommended products first
        combinedProducts.addAll(recommendedProducts);

        // Add popular products that aren't already in recommendations
        final recommendedIds = recommendedProducts.map((p) => p.id).toSet();
        final additionalPopular = popularProducts
            .where((p) => !recommendedIds.contains(p.id))
            .take(20 - recommendedProducts.length)
            .toList();

        combinedProducts.addAll(additionalPopular);
        return combinedProducts;
      }

      return recommendedProducts;
    } catch (e) {
      print('Error loading recommendations: $e');
      // On error, fallback to popular products
      return _getPopularProducts();
    }
  }

  Future<List<Product>> _getPopularProducts() async {
    try {
      // Try to get products ordered by viewCount first
      var popularSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .orderBy('viewCount', descending: true)
          .limit(20)
          .get();

      if (popularSnapshot.docs.isNotEmpty) {
        print('Found ${popularSnapshot.docs.length} products ordered by viewCount');
        return popularSnapshot.docs
            .map((doc) => Product.fromDocument(doc.data(), doc.id))
            .toList();
      }

      // If no products with viewCount, fallback to recent products
      print('No products with viewCount found, falling back to recent products');
      popularSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      if (popularSnapshot.docs.isNotEmpty) {
        return popularSnapshot.docs
            .map((doc) => Product.fromDocument(doc.data(), doc.id))
            .toList();
      }

      // Last resort: get any products available
      print('No recent products found, getting any available products');
      popularSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .limit(20)
          .get();

      return popularSnapshot.docs
          .map((doc) => Product.fromDocument(doc.data(), doc.id))
          .toList();

    } catch (e) {
      print('Error loading popular products: $e');
      // Return empty list if all fails
      return [];
    }
  }

  Future<Map<String, dynamic>> _getRecommendationStats() async {
    try {
      final metadataDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('recommendations')
          .doc('_metadata')
          .get();

      final data = metadataDoc.data() ?? {};

      return {
        'totalViews': data['basedOnViews'] ?? 0,
        'totalPurchases': data['basedOnPurchases'] ?? 0,
        'totalRecommendations': data['totalRecommendations'] ?? 0,
        'basedOnViews': data['basedOnViews'] ?? 0,
        'basedOnPurchases': data['basedOnPurchases'] ?? 0,
        'lastGenerated': data['generatedAt']?.toDate()?.toString(),
      };
    } catch (e) {
      print('Error getting recommendation stats from _metadata: $e');
      return {
        'totalViews': 0,
        'totalPurchases': 0,
        'totalRecommendations': 0,
        'basedOnViews': 0,
        'basedOnPurchases': 0,
        'lastGenerated': null,
      };
    }
  }

  Widget _buildDebugInfo() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getRecommendationStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final stats = snapshot.data!;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Debug Info:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('User ID: ${widget.userId ?? "Not logged in"}'),
              Text('Total Views: ${stats['totalViews']}'),
              Text('Total Purchases: ${stats['totalPurchases']}'),
              Text('Recommendations: ${stats['totalRecommendations']}'),
              Text('Based on Views: ${stats['basedOnViews']}'),
              Text('Based on Purchases: ${stats['basedOnPurchases']}'),
              if (stats['lastGenerated'] != null)
                Text('Last Generated: ${stats['lastGenerated']}'),
            ],
          ),
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant RecommendationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      print('UserId changed from ${oldWidget.userId} to ${widget.userId}');
      _currentUserId = widget.userId;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('RecommendationsSection build called at ${DateTime.now()} for user: ${widget.userId}');

    // Only rebuild if userId has changed
    if (_currentUserId != widget.userId) {
      _currentUserId = widget.userId;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show debug info if enabled
        if (widget.showDebugInfo) _buildDebugInfo(),

        // Main recommendations content
        FutureBuilder<List<Product>>(
          future: _getRecommendedProducts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 270,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              print('Error in FutureBuilder: ${snapshot.error}');
              return SizedBox(
                height: 270,
                child: Center(
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
                ),
              );
            }

            final products = snapshot.data ?? [];

            if (products.isEmpty) {
              return SizedBox(
                height: 270,
                child: Center(
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
                ),
              );
            }

            print('Displaying ${products.length} products');
            return SizedBox(
              height: 270,
              child: ListView.builder(
                itemCount: products.length,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: SizedBox(
                      width: 160,
                      child: ProductSmallCard(product: product),
                    ),
                  );
                },
              ),
            );
          },
        )
      ],
    );
  }
}