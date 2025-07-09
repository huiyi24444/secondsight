// recommendation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../model/product_model.dart';
import '../model/product_rec_model.dart';

class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache recommendations to reduce Firebase reads
  final Map<String, List<ProductRecommendation>> _recommendationCache = {};

  /// Get recommendations for a specific product
  Future<List<ProductRecommendation>> getRecommendations(String productId) async {
    // Check cache first
    if (_recommendationCache.containsKey(productId)) {
      return _recommendationCache[productId]!;
    }

    try {
      final docSnapshot = await _firestore
          .collection('recommendations')
          .doc(productId)
          .get();

      if (!docSnapshot.exists) {
        return [];
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      final recommendationsList = data['recommendations'] as List<dynamic>;

      final recommendations = recommendationsList
          .map((rec) => ProductRecommendation.fromMap(rec))
          .toList();

      // Cache the results
      _recommendationCache[productId] = recommendations;

      return recommendations;
    } catch (e) {
      debugPrint('Error fetching recommendations: $e');
      return [];
    }
  }

  /// Get product details for multiple product IDs
  Future<List<Product>> getProductsByIds(List<String> productIds) async {
    if (productIds.isEmpty) return [];

    try {
      // Firebase allows querying up to 10 items with whereIn
      final List<Product> allProducts = [];

      for (int i = 0; i < productIds.length; i += 10) {
        final batch = productIds.skip(i).take(10).toList();

        final querySnapshot = await _firestore
            .collection('products')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        final products = querySnapshot.docs
            .map((doc) => Product.fromDocumentSnapshot(doc))
            .toList();

        allProducts.addAll(products);
      }

      return allProducts;
    } catch (e) {
      debugPrint('Error fetching products by IDs: $e');
      return [];
    }
  }

  /// Get personalized recommendations based on user's browsing history
  Future<List<Product>> getPersonalizedRecommendations(String userId) async {
    try {
      // Get user's recently viewed products
      final viewHistory = await _getUserViewHistory(userId);

      if (viewHistory.isEmpty) {
        // Return popular products if no history
        return await getPopularProducts();
      }

      // Get recommendations for recently viewed products
      final Set<String> recommendedProductIds = {};

      for (String productId in viewHistory.take(5)) {
        final recommendations = await getRecommendations(productId);

        for (var rec in recommendations.take(3)) {
          recommendedProductIds.add(rec.productId);
        }
      }

      // Remove already viewed products
      recommendedProductIds.removeAll(viewHistory);

      // Fetch product details
      return await getProductsByIds(recommendedProductIds.toList());
    } catch (e) {
      debugPrint('Error getting personalized recommendations: $e');
      return [];
    }
  }

  /// Get user's view history
  Future<List<String>> _getUserViewHistory(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('viewHistory')
          .orderBy('viewedAt', descending: true)
          .limit(10)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data()['productId'] as String)
          .toList();
    } catch (e) {
      debugPrint('Error fetching view history: $e');
      return [];
    }
  }

  /// Get popular products as fallback
  Future<List<Product>> getPopularProducts() async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('productStatus', isEqualTo: 'available')
          .orderBy('viewCount', descending: true)
          .limit(10)
          .get();

      return querySnapshot.docs
          .map((doc) => Product.fromDocumentSnapshot(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching popular products: $e');
      return [];
    }
  }

  /// Clear recommendation cache
  void clearCache() {
    _recommendationCache.clear();
  }
}
