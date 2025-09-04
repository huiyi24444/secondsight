// offline_recommendation_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class OfflineRecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache system
  List<PersonalizedRecommendation>? _cachedRecommendations;
  DateTime? _lastFetched;
  bool _isCurrentlyGenerating = false;
  List<Map<String, dynamic>>? _cachedProducts;
  UserPreferences? _cachedUserPreferences;
  final Map<String, String> _categoryCache = {};

  /// Resolve category from DocumentReference or String
  Future<String> resolveCategory(dynamic catField) async {
    if (catField is String) return catField;

    if (catField is DocumentReference) {
      if (_categoryCache.containsKey(catField.path)) {
        return _categoryCache[catField.path]!;
      }
      try {
        final snap = await catField.get();
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>?;
          final name = data?['catName'] ?? catField.id;
          _categoryCache[catField.path] = name;
          return name;
        }
        return catField.id;
      } catch (_) {
        return catField.id;
      }
    }
    return 'unknown';
  }

  /// Get personalized recommendations for current user
  Future<List<PersonalizedRecommendation>> getPersonalizedRecommendations({
    bool forceRefresh = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    // Prevent concurrent generation
    if (_isCurrentlyGenerating && !forceRefresh) {
      while (_isCurrentlyGenerating) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _cachedRecommendations ?? [];
    }

    // Check cache validity (1 hour)
    if (!forceRefresh &&
        _cachedRecommendations != null &&
        _lastFetched != null &&
        DateTime.now().difference(_lastFetched!) < const Duration(hours: 1)) {
      return _cachedRecommendations!;
    }

    _isCurrentlyGenerating = true;
    try {
      final recommendations = await _generateOfflineRecommendations(user.uid);
      await _saveRecommendationsToFirestore(user.uid, recommendations);

      _cachedRecommendations = recommendations;
      _lastFetched = DateTime.now();
      return recommendations;
    } catch (e) {
      debugPrint('Error generating recommendations: $e');
      return await _getFallbackRecommendations(user.uid);
    } finally {
      _isCurrentlyGenerating = false;
    }
  }

  /// Generate recommendations using offline ML
  Future<List<PersonalizedRecommendation>> _generateOfflineRecommendations(String userId) async {
    final preferences = await _getUserPreferences(userId);

    // New users get popular items
    if (preferences.viewedProducts.isEmpty && preferences.purchasedProducts.isEmpty) {
      return await _generateDefaultRecommendations(userId);
    }

    final allProducts = await _getAllProducts();
    if (allProducts.length < 2) return [];

    return await _generateContentBasedRecommendations(preferences, allProducts);
  }

  /// Build user preferences from interaction history
  Future<UserPreferences> _getUserPreferences(String userId) async {
    if (_cachedUserPreferences != null) return _cachedUserPreferences!;

    final preferences = UserPreferences();

    try {
      // Get view history
      final viewHistory = await _firestore
          .collection('users')
          .doc(userId)
          .collection('viewHistory')
          .orderBy('viewedAt', descending: true)
          .limit(50)
          .get();

      final viewedProductIds = viewHistory.docs
          .map((doc) => doc.data()['productId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      // Get purchase history
      final orders = await _firestore
          .collection('users')
          .doc(userId)
          .collection('order')
          .get();

      final purchasedProductIds = <String>[];
      for (var order in orders.docs) {
        final orderProducts = await _firestore
            .collection('users')
            .doc(userId)
            .collection('order')
            .doc(order.id)
            .collection('orderProducts')
            .get();

        for (var orderProduct in orderProducts.docs) {
          final productRef = orderProduct.data()['productID'];
          String? productId;

          if (productRef is DocumentReference) {
            productId = productRef.id;
          } else if (productRef is String) {
            productId = productRef;
          }

          if (productId != null) purchasedProductIds.add(productId);
        }
      }

      // Fetch product details in batches
      final combinedProductIds = [...viewedProductIds, ...purchasedProductIds].toSet().toList();

      for (int i = 0; i < combinedProductIds.length; i += 10) {
        final batchIds = combinedProductIds.skip(i).take(10).toList();
        final products = await _firestore
            .collection('products')
            .where(FieldPath.documentId, whereIn: batchIds)
            .where('productStatus', isEqualTo: 'available')
            .get();

        for (var product in products.docs) {
          final productData = product.data();
          productData['id'] = product.id;

          // Build preference maps
          final categoryId = await resolveCategory(productData['category']);
          preferences.favoriteCategories[categoryId] =
              (preferences.favoriteCategories[categoryId] ?? 0) + 1;

          final condition = productData['productCondition'] as String? ?? 'unknown';
          preferences.preferredConditions[condition] =
              (preferences.preferredConditions[condition] ?? 0) + 1;

          final tags = productData['tags'] as List<dynamic>? ?? [];
          for (var tag in tags) {
            if (tag is String) {
              preferences.preferredTags[tag] =
                  (preferences.preferredTags[tag] ?? 0) + 1;
            }
          }

          // Track price range
          final price = (productData['productPrice'] as num?)?.toDouble() ?? 0.0;
          if (price > 0) {
            preferences.priceRange['min'] =
            preferences.priceRange['min'] == null ? price : min(preferences.priceRange['min']!, price);
            preferences.priceRange['max'] =
            preferences.priceRange['max'] == null ? price : max(preferences.priceRange['max']!, price);
          }

          // Add to appropriate lists
          if (viewedProductIds.contains(product.id)) {
            preferences.viewedProducts.add(ProductInfo(id: product.id, data: productData));
          }
          if (purchasedProductIds.contains(product.id)) {
            preferences.purchasedProducts.add(ProductInfo(id: product.id, data: productData));
          }
        }
      }

      _cachedUserPreferences = preferences;
      return preferences;
    } catch (e) {
      debugPrint('Error getting user preferences: $e');
      return preferences;
    }
  }

  /// Get all available products
  Future<List<Map<String, dynamic>>> _getAllProducts() async {
    if (_cachedProducts != null) return _cachedProducts!;

    try {
      final productsSnapshot = await _firestore
          .collection('products')
          .where('productStatus', isEqualTo: 'available')
          .get();

      final products = productsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _cachedProducts = products;
      return products;
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  /// Generate content-based recommendations
  Future<List<PersonalizedRecommendation>> _generateContentBasedRecommendations(
      UserPreferences preferences, List<Map<String, dynamic>> allProducts) async {

    final userVector = _createUserPreferenceVector(preferences);
    final interactedIds = preferences.purchasedProducts.map((p) => p.id).toSet();
    final productSimilarities = <ProductSimilarity>[];

    // Calculate similarities
    for (var product in allProducts) {
      final productId = product['id'] as String;
      if (interactedIds.contains(productId)) continue;

      final productVector = await _createProductVector(product);
      final similarity = _calculateCosineSimilarity(userVector, productVector);

      if (similarity > 0.01) {
        productSimilarities.add(ProductSimilarity(
            product: product,
            similarity: similarity
        ));
      }
    }

    // Sort and apply boosts
    productSimilarities.sort((a, b) => b.similarity.compareTo(a.similarity));
    final recommendations = <PersonalizedRecommendation>[];

    for (int i = 0; i < min(20, productSimilarities.length); i++) {
      final productSim = productSimilarities[i];
      final product = productSim.product;
      double score = productSim.similarity;

      // Apply preference boosts
      final category = await resolveCategory(product['category']);
      if (preferences.favoriteCategories.containsKey(category)) score *= 1.2;

      final condition = product['productCondition'] as String?;
      if (condition != null && preferences.preferredConditions.containsKey(condition)) {
        score *= 1.1;
      }

      final productTags = (product['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      final commonTags = productTags.where((tag) => preferences.preferredTags.containsKey(tag)).toList();
      if (commonTags.isNotEmpty) score *= 1.15;

      final urls = product['productURL'];
      final productUrl = urls is List && urls.isNotEmpty ? urls[0] : '';

      recommendations.add(PersonalizedRecommendation(
        productId: product['id'] as String,
        productName: product['productName'] as String? ?? '',
        productPrice: (product['productPrice'] as num?)?.toDouble() ?? 0.0,
        productURL: productUrl,
        similarityScore: score,
        category: category ?? '',
        tags: productTags,
        rank: i + 1,
        reason: await _getRecommendationReason(product, preferences),
      ));
    }

    return recommendations;
  }

  /// Create user preference vector
  Map<String, double> _createUserPreferenceVector(UserPreferences preferences) {
    final vector = <String, double>{};

    // Purchased items (highest weight)
    for (var product in preferences.purchasedProducts) {
      final productName = product.data['productName'] as String?;
      if (productName != null) {
        _addToVector(vector, productName.toLowerCase().split(' '), 5.0);
      }
      final tags = product.data['tags'] as List<dynamic>?;
      if (tags != null) {
        _addToVector(vector, tags.cast<String>(), 3.0);
      }
    }

    // Viewed items
    for (var product in preferences.viewedProducts.take(20)) {
      final productName = product.data['productName'] as String?;
      if (productName != null) {
        _addToVector(vector, productName.toLowerCase().split(' '), 2.0);
      }
      final tags = product.data['tags'] as List<dynamic>?;
      if (tags != null) {
        _addToVector(vector, tags.cast<String>(), 1.0);
      }
    }

    // Preferred tags and conditions
    for (var entry in preferences.preferredTags.entries) {
      final weight = min(entry.value.toDouble(), 5.0);
      vector[entry.key.toLowerCase()] = (vector[entry.key.toLowerCase()] ?? 0) + weight;
    }

    for (var entry in preferences.preferredConditions.entries) {
      final weight = min(entry.value.toDouble(), 3.0);
      vector[entry.key.toLowerCase()] = (vector[entry.key.toLowerCase()] ?? 0) + weight;
    }

    return vector;
  }

  /// Create product vector for similarity calculation
  Future<Map<String, double>> _createProductVector(Map<String, dynamic> product) async {
    final vector = <String, double>{};

    final productName = product['productName'] as String?;
    if (productName != null) {
      _addToVector(vector, productName.toLowerCase().split(' '), 3.0);
    }

    final productDesc = product['productDesc'] as String?;
    if (productDesc != null) {
      _addToVector(vector, productDesc.toLowerCase().split(' '), 1.0);
    }

    final tags = product['tags'] as List<dynamic>?;
    if (tags != null) {
      _addToVector(vector, tags.cast<String>(), 2.0);
    }

    final condition = product['productCondition'] as String?;
    if (condition != null) {
      vector[condition.toLowerCase()] = (vector[condition.toLowerCase()] ?? 0) + 1.0;
    }

    final resolvedCategory = await resolveCategory(product['category']);
    if (resolvedCategory.isNotEmpty && resolvedCategory != 'unknown') {
      vector[resolvedCategory.toLowerCase()] =
          (vector[resolvedCategory.toLowerCase()] ?? 0) + 2.0;
    }

    return vector;
  }

  /// Add terms to vector with weight
  void _addToVector(Map<String, double> vector, List<String> terms, double weight) {
    for (var term in terms) {
      final cleanTerm = term.toLowerCase().trim();
      if (cleanTerm.isNotEmpty) {
        vector[cleanTerm] = (vector[cleanTerm] ?? 0) + weight;
      }
    }
  }

  /// Calculate cosine similarity
  double _calculateCosineSimilarity(Map<String, double> vectorA, Map<String, double> vectorB) {
    if (vectorA.isEmpty || vectorB.isEmpty) return 0.0;

    final allTerms = <String>{...vectorA.keys, ...vectorB.keys};
    double dotProduct = 0.0, magnitudeA = 0.0, magnitudeB = 0.0;

    for (var term in allTerms) {
      final valueA = vectorA[term] ?? 0.0;
      final valueB = vectorB[term] ?? 0.0;
      dotProduct += valueA * valueB;
      magnitudeA += valueA * valueA;
      magnitudeB += valueB * valueB;
    }

    if (magnitudeA == 0.0 || magnitudeB == 0.0) return 0.0;
    return dotProduct / (sqrt(magnitudeA) * sqrt(magnitudeB));
  }

  /// Generate recommendation reason
  Future<String> _getRecommendationReason(Map<String, dynamic> product, UserPreferences preferences) async {
    final reasons = <RecommendationReason>[];

    // Tag matches (highest priority)
    final productTags = (product['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    final commonTags = productTags.where((tag) => preferences.preferredTags.containsKey(tag)).toList();
    if (commonTags.isNotEmpty) {
      final totalTagWeight = commonTags.fold(0, (sum, tag) => sum + (preferences.preferredTags[tag] ?? 0));
      reasons.add(RecommendationReason(
        text: 'Matches your interests: ${commonTags.take(2).join(', ')}',
        priority: 1,
        specificity: totalTagWeight.toDouble(),
      ));
    }

    // Category match
    final category = await resolveCategory(product['category']);
    if (category != null && preferences.favoriteCategories.containsKey(category)) {
      final categoryCount = preferences.favoriteCategories[category]!;
      reasons.add(RecommendationReason(
        text: 'Similar to your favorite category',
        priority: 2,
        specificity: categoryCount.toDouble(),
      ));
    }

    // Similar to viewed items
    final productName = product['productName'] as String? ?? '';
    final productWords = productName.toLowerCase().split(' ').where((w) => w.length > 2).toSet();

    for (var viewedProduct in preferences.viewedProducts.take(10)) {
      final viewedName = viewedProduct.data['productName'] as String? ?? '';
      final viewedWords = viewedName.toLowerCase().split(' ').where((w) => w.length > 2).toSet();
      final commonWords = productWords.intersection(viewedWords);

      if (commonWords.length >= 2) {
        reasons.add(RecommendationReason(
          text: 'Similar to "${viewedName.length > 30 ? '${viewedName.substring(0, 30)}...' : viewedName}"',
          priority: 1,
          specificity: commonWords.length.toDouble(),
        ));
        break;
      }
    }

    if (reasons.isEmpty) return 'Based on your browsing history';

    // Sort by priority and specificity
    reasons.sort((a, b) {
      final priorityComparison = a.priority.compareTo(b.priority);
      if (priorityComparison != 0) return priorityComparison;
      return b.specificity.compareTo(a.specificity);
    });

    final bestReasons = reasons.where((r) => r.priority == reasons.first.priority).toList();
    if (bestReasons.length > 1) {
      return bestReasons[Random().nextInt(bestReasons.length)].text;
    }

    return reasons.first.text;
  }

  /// Generate default recommendations for new users
  Future<List<PersonalizedRecommendation>> _generateDefaultRecommendations(String userId) async {
    try {
      final popularProducts = await _firestore
          .collection('products')
          .where('productStatus', isEqualTo: 'available')
          .orderBy('viewCount', descending: true)
          .limit(20)
          .get();

      final recommendations = <PersonalizedRecommendation>[];

      for (int i = 0; i < popularProducts.docs.length; i++) {
        final product = popularProducts.docs[i];
        final productData = product.data();
        final urls = productData['productURL'];
        final productUrl = urls is List && urls.isNotEmpty ? urls[0] : '';

        recommendations.add(PersonalizedRecommendation(
          productId: product.id,
          productName: productData['productName'] as String? ?? '',
          productPrice: (productData['productPrice'] as num?)?.toDouble() ?? 0.0,
          productURL: productUrl,
          similarityScore: 0.01,
          reason: 'Popular item',
          rank: i + 1,
          tags: (productData['tags'] as List<dynamic>?)?.cast<String>() ?? [],
          category: await resolveCategory(productData['category']),
        ));
      }

      return recommendations;
    } catch (e) {
      debugPrint('Error generating default recommendations: $e');
      return [];
    }
  }

  /// Save recommendations to Firestore
  Future<void> _saveRecommendationsToFirestore(String userId, List<PersonalizedRecommendation> recommendations) async {
    try {
      final recommendationsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('recommendations');

      final batch = _firestore.batch();

      // Clear old recommendations
      final oldRecs = await recommendationsRef.get();
      for (var doc in oldRecs.docs) {
        batch.delete(doc.reference);
      }

      // Save metadata
      batch.set(recommendationsRef.doc('_metadata'), {
        'generatedAt': FieldValue.serverTimestamp(),
        'totalRecommendations': recommendations.length,
        'basedOnViews': _cachedUserPreferences?.viewedProducts.length ?? 0,
        'basedOnPurchases': _cachedUserPreferences?.purchasedProducts.length ?? 0,
        'version': '3.0-offline',
      });

      // Save recommendations
      for (int i = 0; i < recommendations.length; i++) {
        final rec = recommendations[i];
        batch.set(recommendationsRef.doc('rec_${i.toString().padLeft(3, '0')}'), {
          'productId': rec.productId,
          'productName': rec.productName,
          'productPrice': rec.productPrice,
          'productURL': rec.productURL,
          'similarityScore': rec.similarityScore,
          'reason': rec.reason,
          'rank': rec.rank,
          'tags': rec.tags,
          'category': rec.category,
          'generatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error saving recommendations: $e');
    }
  }

  /// Get fallback recommendations from Firestore
  Future<List<PersonalizedRecommendation>> _getFallbackRecommendations(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recommendations')
          .where('rank', isLessThanOrEqualTo: 20)
          .orderBy('rank')
          .get();

      return snapshot.docs
          .where((doc) => doc.id != '_metadata')
          .map((doc) => PersonalizedRecommendation.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting fallback recommendations: $e');
      return [];
    }
  }

  /// Track product view
  Future<void> trackProductView(String productId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('viewHistory')
          .add({
        'productId': productId,
        'viewedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('products').doc(productId).update({
        'viewCount': FieldValue.increment(1),
      });

      // Clear cache to trigger regeneration
      _cachedUserPreferences = null;
      _cachedRecommendations = null;
    } catch (e) {
      debugPrint('Error tracking product view: $e');
    }
  }

  /// Clear all caches
  void clearCache() {
    _cachedRecommendations = null;
    _cachedUserPreferences = null;
    _cachedProducts = null;
    _lastFetched = null;
  }

  /// Manually trigger recommendation generation
  Future<bool> generateRecommendations({bool showProgress = false}) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      if (showProgress) debugPrint('Generating offline recommendations...');
      clearCache();
      final recommendations = await getPersonalizedRecommendations(forceRefresh: true);
      if (showProgress) debugPrint('Generated ${recommendations.length} recommendations');
      return recommendations.isNotEmpty;
    } catch (e) {
      debugPrint('Error generating recommendations: $e');
      return false;
    }
  }
}

// Data Models
class UserPreferences {
  final List<ProductInfo> viewedProducts = [];
  final List<ProductInfo> purchasedProducts = [];
  final Map<String, int> favoriteCategories = {};
  final Map<String, int> preferredConditions = {};
  final Map<String, int> preferredTags = {};
  final Map<String, double?> priceRange = {'min': null, 'max': null};
}

class ProductInfo {
  final String id;
  final Map<String, dynamic> data;
  ProductInfo({required this.id, required this.data});
}

class ProductSimilarity {
  final Map<String, dynamic> product;
  final double similarity;
  ProductSimilarity({required this.product, required this.similarity});
}

class PersonalizedRecommendation {
  final String productId;
  final String productName;
  final double productPrice;
  final String productURL;
  final double similarityScore;
  final String reason;
  final int rank;
  final List<String> tags;
  final String? category;

  PersonalizedRecommendation({
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.productURL,
    required this.similarityScore,
    required this.reason,
    required this.rank,
    required this.tags,
    this.category,
  });

  factory PersonalizedRecommendation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PersonalizedRecommendation(
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      productPrice: (data['productPrice'] ?? 0).toDouble(),
      productURL: data['productURL'] ?? '',
      similarityScore: (data['similarityScore'] ?? 0).toDouble(),
      reason: data['reason'] ?? 'Recommended for you',
      rank: data['rank'] ?? 0,
      tags: List<String>.from(data['tags'] ?? []),
      category: data['category'],
    );
  }
}

class RecommendationReason {
  final String text;
  final int priority;
  final double specificity;

  RecommendationReason({
    required this.text,
    required this.priority,
    required this.specificity,
  });
}