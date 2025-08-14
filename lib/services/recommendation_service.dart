// offline_recommendation_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class OfflineRecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for recommendations and user data
  List<PersonalizedRecommendation>? _cachedRecommendations;
  DateTime? _lastFetched;
  bool _isCurrentlyGenerating = false;

  // Cache for products and user preferences
  List<Map<String, dynamic>>? _cachedProducts;
  UserPreferences? _cachedUserPreferences;

  // ✅ Add category cache here
  final Map<String, String> _categoryCache = {};

  // ✅ Add resolver function here
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
    if (user == null) {
      return [];
    }

    // Prevent multiple simultaneous calls
    if (_isCurrentlyGenerating && !forceRefresh) {
      while (_isCurrentlyGenerating) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _cachedRecommendations ?? [];
    }

    // Check cache (valid for 1 hour)
    if (!forceRefresh &&
        _cachedRecommendations != null &&
        _lastFetched != null &&
        DateTime.now().difference(_lastFetched!) < const Duration(hours: 1)) {
      return _cachedRecommendations!;
    }

    _isCurrentlyGenerating = true;
    try {
      // Generate recommendations offline
      final recommendations = await _generateOfflineRecommendations(user.uid);

      // Save to Firestore for persistence
      await _saveRecommendationsToFirestore(user.uid, recommendations);

      _cachedRecommendations = recommendations;
      _lastFetched = DateTime.now();

      return recommendations;
    } catch (e) {
      debugPrint('Error generating offline recommendations: $e');
      // Fallback to cached or Firestore recommendations
      return await _getFallbackRecommendations(user.uid);
    } finally {
      _isCurrentlyGenerating = false;
    }
  }

  /// Generate recommendations using offline machine learning
  Future<List<PersonalizedRecommendation>> _generateOfflineRecommendations(String userId) async {
    debugPrint('Generating offline recommendations for user: $userId');

    // Get user preferences
    final preferences = await _getUserPreferences(userId);
    debugPrint("viewedProducts count: ${preferences.viewedProducts.length}");
    debugPrint("purchasedProducts count: ${preferences.purchasedProducts.length}");


    // If no interaction history, return popular items
    if (preferences.viewedProducts.isEmpty && preferences.purchasedProducts.isEmpty) {
      return await _generateDefaultRecommendations(userId);
    }

    // Get all available products
    final allProducts = await _getAllProducts();

    if (allProducts.length < 2) {
      debugPrint('Not enough products for recommendations');
      return [];
    }

    // Generate recommendations using content-based filtering
    final recommendations = await _generateContentBasedRecommendations(
        preferences,
        allProducts
    );

    return recommendations;
  }

  /// Get user preferences from interaction history
  Future<UserPreferences> _getUserPreferences(String userId) async {
    // Check cache first
    if (_cachedUserPreferences != null) {
      return _cachedUserPreferences!;
    }

    final preferences = UserPreferences();

    try {
      // Get user's view history
      final viewHistory = await _firestore
          .collection('users')
          .doc(userId)
          .collection('viewHistory')
          .orderBy('viewedAt', descending: true)
          .limit(50)
          .get();

      List<String> viewedProductIds = [];
      for (var view in viewHistory.docs) {
        final productId = view.data()['productId'] as String?;
        if (productId != null) {
          viewedProductIds.add(productId);
        }
      }

      // Get user's purchase history
      final orders = await _firestore
          .collection('users')
          .doc(userId)
          .collection('order')
          .get();

      List<String> purchasedProductIds = [];
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

          if (productId != null) {
            purchasedProductIds.add(productId);
          }
        }

      }

      // Fetch product details for viewed and purchased items
      final combinedProductIds = [...viewedProductIds, ...purchasedProductIds].toSet().toList();

      if (combinedProductIds.isNotEmpty) {
        // Fetch products in batches (Firestore limit: 10 per query)
        for (int i = 0; i < combinedProductIds.length; i += 10) {
          final batchIds = combinedProductIds.skip(i).take(10).toList();

          final products = await _firestore
              .collection('products')
              .where(FieldPath.documentId, whereIn: batchIds)
              .where('productStatus', isEqualTo: 'available') // ✅ ADD THIS LINE
              .get();


          for (var product in products.docs) {
            final productData = product.data();
            productData['id'] = product.id;


            // Track categories
            final categoryId = await resolveCategory(productData['category']);


            preferences.favoriteCategories[categoryId] =
                (preferences.favoriteCategories[categoryId] ?? 0) + 1;


            // Track conditions
            final condition = productData['productCondition'] as String? ?? 'unknown';
            preferences.preferredConditions[condition] =
                (preferences.preferredConditions[condition] ?? 0) + 1;

            // Track tags
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
              if (preferences.priceRange['min'] == null || price < preferences.priceRange['min']!) {
                preferences.priceRange['min'] = price;
              }
              if (preferences.priceRange['max'] == null || price > preferences.priceRange['max']!) {
                preferences.priceRange['max'] = price;
              }
            }

            // Add to appropriate lists
            if (viewedProductIds.contains(product.id)) {
              preferences.viewedProducts.add(ProductInfo(
                id: product.id,
                data: productData,
              ));
            }
            if (purchasedProductIds.contains(product.id)) {
              preferences.purchasedProducts.add(ProductInfo(
                id: product.id,
                data: productData,
              ));
            }
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
    // Check cache first
    if (_cachedProducts != null) {
      return _cachedProducts!;
    }

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
      debugPrint('Error getting all products: $e');
      return [];
    }
  }

  List<PersonalizedRecommendation> _filterAvailableRecommendations(
      List<PersonalizedRecommendation> recommendations,
      List<Map<String, dynamic>> allProducts
      ) {
    final availableProductIds = allProducts
        .where((product) => product['productStatus'] == 'available')
        .map((product) => product['id'] as String)
        .toSet();

    return recommendations
        .where((rec) => availableProductIds.contains(rec.productId))
        .toList();
  }

  /// Generate content-based recommendations
  Future<List<PersonalizedRecommendation>> _generateContentBasedRecommendations(
      UserPreferences preferences,
      List<Map<String, dynamic>> allProducts
      ) async {
    // Create user preference vector
    final userVector = _createUserPreferenceVector(preferences);


    // Get already interacted products to exclude
    final interactedIds = <String>{};
    for (var product in preferences.purchasedProducts) {
      interactedIds.add(product.id);
    }

    // Calculate similarity scores for all products
    final List<ProductSimilarity> productSimilarities = [];

    for (var product in allProducts) {
      final productId = product['id'] as String;

      // Skip already interacted products
      if (interactedIds.contains(productId)) {
        continue;
      }

      // Create product vector
      final productVector = await _createProductVector(product);

      // Calculate cosine similarity
      final similarity = _calculateCosineSimilarity(userVector, productVector);

      if (similarity > 0.01) { // Threshold for relevance
        productSimilarities.add(ProductSimilarity(
          product: product,
          similarity: similarity,
        ));
      }
    }


    // Sort by similarity score
    productSimilarities.sort((a, b) => b.similarity.compareTo(a.similarity));

    // Apply preference boosts and create recommendations
    final recommendations = <PersonalizedRecommendation>[];

    for (int i = 0; i < min(20, productSimilarities.length); i++) {
      final productSim = productSimilarities[i];
      final product = productSim.product;
      double score = productSim.similarity;

      final category = await resolveCategory(product['category']);

      if (category != null && preferences.favoriteCategories.containsKey(category)) {
        score *= 1.2;
      }

      final condition = product['productCondition'] as String?;
      if (condition != null && preferences.preferredConditions.containsKey(condition)) {
        score *= 1.1;
      }

      // Check tag overlap
      final productTags = (product['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      final commonTags = productTags.where((tag) => preferences.preferredTags.containsKey(tag)).toList();
      if (commonTags.isNotEmpty) {
        score *= 1.15;
      }

      // Handle productURL
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
    debugPrint("Total available products: ${allProducts.length}");
    debugPrint("Filtered product similarities: ${productSimilarities.length}");

    final filteredRecommendations = _filterAvailableRecommendations(recommendations, allProducts);
    return filteredRecommendations;
  }

  /// Create user preference vector from interaction history
  Map<String, double> _createUserPreferenceVector(UserPreferences preferences) {
    final vector = <String, double>{};

    // Weight purchased items highest
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

    // Weight viewed items
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

    // Add preferred tags with weights
    for (var entry in preferences.preferredTags.entries) {
      final weight = min(entry.value.toDouble(), 5.0);
      vector[entry.key.toLowerCase()] = (vector[entry.key.toLowerCase()] ?? 0) + weight;
    }

    // Add preferred conditions
    for (var entry in preferences.preferredConditions.entries) {
      final weight = min(entry.value.toDouble(), 3.0);
      vector[entry.key.toLowerCase()] = (vector[entry.key.toLowerCase()] ?? 0) + weight;
    }

    return vector;
  }

  /// Create product vector for similarity calculation
  Future<Map<String, double>> _createProductVector(Map<String, dynamic> product) async {
    final vector = <String, double>{};

    // Product name (highest weight)
    final productName = product['productName'] as String?;
    if (productName != null) {
      _addToVector(vector, productName.toLowerCase().split(' '), 3.0);
    }

    // Product description
    final productDesc = product['productDesc'] as String?;
    if (productDesc != null) {
      _addToVector(vector, productDesc.toLowerCase().split(' '), 1.0);
    }

    // Tags (high weight)
    final tags = product['tags'] as List<dynamic>?;
    if (tags != null) {
      _addToVector(vector, tags.cast<String>(), 2.0);
    }

    // Product condition
    final condition = product['productCondition'] as String?;
    if (condition != null) {
      vector[condition.toLowerCase()] = (vector[condition.toLowerCase()] ?? 0) + 1.0;
    }

    // Category (medium weight)
    final dynamic categoryField = product['category'];
    final resolvedCategory = await resolveCategory(categoryField);
    if (resolvedCategory.isNotEmpty && resolvedCategory != 'unknown') {
      vector[resolvedCategory.toLowerCase()] =
          (vector[resolvedCategory.toLowerCase()] ?? 0) + 2.0;
    }


    return vector;
  }

  /// Add terms to vector with specified weight
  void _addToVector(Map<String, double> vector, List<String> terms, double weight) {
    for (var term in terms) {
      final cleanTerm = term.toLowerCase().trim();
      if (cleanTerm.isNotEmpty) {
        vector[cleanTerm] = (vector[cleanTerm] ?? 0) + weight;
      }
    }
  }

  /// Calculate cosine similarity between two vectors
  double _calculateCosineSimilarity(Map<String, double> vectorA, Map<String, double> vectorB) {
    if (vectorA.isEmpty || vectorB.isEmpty) return 0.0;

    // Get all unique terms
    final allTerms = <String>{...vectorA.keys, ...vectorB.keys};

    double dotProduct = 0.0;
    double magnitudeA = 0.0;
    double magnitudeB = 0.0;

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

  /// Generate recommendation reason - FIXED VERSION

  /// Generate recommendation reason - FIXED VERSION
  Future<String> _getRecommendationReason(Map<String, dynamic> product, UserPreferences preferences) async {
    final reasons = <RecommendationReason>[];

    // Check category match
    final category = await resolveCategory(product['category']);
    if (category != null && preferences.favoriteCategories.containsKey(category)) {
      final categoryCount = preferences.favoriteCategories[category]!;
      reasons.add(RecommendationReason(
        text: 'Similar to your favorite category',
        priority: 2, // Medium priority
        specificity: categoryCount.toDouble(), // More interactions = higher specificity
      ));
    }

    // Check tag overlap
    final productTags = (product['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    final commonTags = productTags.where((tag) => preferences.preferredTags.containsKey(tag)).toList();
    if (commonTags.isNotEmpty) {
      final totalTagWeight = commonTags.fold(0, (sum, tag) => sum + (preferences.preferredTags[tag] ?? 0));
      reasons.add(RecommendationReason(
        text: 'Matches your interests: ${commonTags.take(2).join(', ')}',
        priority: 1, // Highest priority - most specific
        specificity: totalTagWeight.toDouble(),
      ));
    }

    // Check product condition preference
    final condition = product['productCondition'] as String?;
    if (condition != null && preferences.preferredConditions.containsKey(condition)) {
      final conditionCount = preferences.preferredConditions[condition]!;
      reasons.add(RecommendationReason(
        text: 'Matches your preferred condition: $condition',
        priority: 3, // Lower priority
        specificity: conditionCount.toDouble(),
      ));
    }

    // Check price range
    if (preferences.purchasedProducts.isNotEmpty) {
      final validPrices = preferences.purchasedProducts
          .map((p) => (p.data['productPrice'] as num?)?.toDouble() ?? 0.0)
          .where((price) => price > 0)
          .toList();

      if (validPrices.isNotEmpty) {
        final avgPrice = validPrices.fold(0.0, (sum, price) => sum + price) / validPrices.length;

        final productPrice = (product['productPrice'] as num?)?.toDouble() ?? 0.0;
        if (productPrice > 0 && (productPrice - avgPrice).abs() < avgPrice * 0.3) {
          reasons.add(RecommendationReason(
            text: 'In your typical price range (\${productPrice.toStringAsFixed(0)})',
            priority: 4, // Lowest priority
            specificity: 1.0,
          ));
        }
      }
    }

    // Check if similar to recently viewed items
    final productName = product['productName'] as String? ?? '';
    final productWords = productName.toLowerCase().split(' ').where((w) => w.length > 2).toSet();

    for (var viewedProduct in preferences.viewedProducts.take(10)) {
      final viewedName = viewedProduct.data['productName'] as String? ?? '';
      final viewedWords = viewedName.toLowerCase().split(' ').where((w) => w.length > 2).toSet();
      final commonWords = productWords.intersection(viewedWords);

      if (commonWords.length >= 2) {
        reasons.add(RecommendationReason(
          text: 'Similar to "${viewedName.length > 30 ? '${viewedName.substring(0, 30)}...' : viewedName}"',
          priority: 1, // High priority - very specific
          specificity: commonWords.length.toDouble(),
        ));
        break; // Only add one similar item reason
      }
    }

    // If no specific reasons found, return default
    if (reasons.isEmpty) {
      return 'Based on your browsing history';
    }

    // Sort by priority (lower number = higher priority), then by specificity (higher = better)
    reasons.sort((a, b) {
      final priorityComparison = a.priority.compareTo(b.priority);
      if (priorityComparison != 0) return priorityComparison;
      return b.specificity.compareTo(a.specificity); // Higher specificity first
    });

    // Return the best reason, with some variety injection
    final bestReasons = reasons.where((r) => r.priority == reasons.first.priority).toList();

    // Add some randomness among equally good reasons to create variety
    if (bestReasons.length > 1) {
      final random = Random();
      return bestReasons[random.nextInt(bestReasons.length)].text;
    }

    return reasons.first.text;
  }


  /// Generate default recommendations for new users
  Future<List<PersonalizedRecommendation>> _generateDefaultRecommendations(String userId) async {
    try {
      final popularProducts = await _firestore
          .collection('products')
          .where('productStatus', isEqualTo: 'available') // ✅ ADD THIS LINE
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

  /// Save recommendations to Firestore for persistence
  Future<void> _saveRecommendationsToFirestore(String userId, List<PersonalizedRecommendation> recommendations) async {
    debugPrint("[DEBUG] Starting to save ${recommendations.length} recommendations for user $userId...");

    try {
      final userRef = _firestore.collection('users').doc(userId);
      final recommendationsRef = userRef.collection('recommendations');

      // Clear old recommendations
      final oldRecs = await recommendationsRef.get();
      debugPrint("[DEBUG] Found ${oldRecs.docs.length} old recommendations. Clearing them...");

      final batch = _firestore.batch();
      for (var doc in oldRecs.docs) {
        debugPrint("[DEBUG] Deleting old recommendation: ${doc.id}");
        batch.delete(doc.reference);
      }

      // Save metadata
      final metaRef = recommendationsRef.doc('_metadata');
      final metaData = {
        'generatedAt': FieldValue.serverTimestamp(),
        'totalRecommendations': recommendations.length,
        'basedOnViews': _cachedUserPreferences?.viewedProducts.length ?? 0,
        'basedOnPurchases': _cachedUserPreferences?.purchasedProducts.length ?? 0,
        'version': '3.0-offline',
      };
      batch.set(metaRef, metaData);
      debugPrint("[DEBUG] Metadata to be saved: $metaData");

      // Save individual recommendations
      for (int i = 0; i < recommendations.length; i++) {
        final rec = recommendations[i];
        final recRef = recommendationsRef.doc('rec_${i.toString().padLeft(3, '0')}');
        final recData = {
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
        };
        batch.set(recRef, recData);
        debugPrint("[DEBUG] Queued rec_${i.toString().padLeft(3, '0')} => $recData");
      }

      await batch.commit();
      debugPrint("[DEBUG] Successfully saved ${recommendations.length} recommendations for user $userId");
    } catch (e, stack) {
      debugPrint("[ERROR] Failed to save recommendations for user $userId: $e");
      debugPrint("[ERROR] Stack trace: $stack");
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

  /// Track product view (same as before)
  Future<void> trackProductView(String productId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Add to view history
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('viewHistory')
          .add({
        'productId': productId,
        'viewedAt': FieldValue.serverTimestamp(),
      });

      // Update product view count
      await _firestore
          .collection('products')
          .doc(productId)
          .update({
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
      if (showProgress) {
        debugPrint('Generating offline recommendations...');
      }

      clearCache();
      final recommendations = await getPersonalizedRecommendations(forceRefresh: true);

      if (showProgress) {
        debugPrint('Generated ${recommendations.length} offline recommendations');
      }

      return recommendations.isNotEmpty;
    } catch (e) {
      debugPrint('Error generating recommendations: $e');
      return false;
    }
  }

  /// Get recommendation metadata
  Future<RecommendationMetadata?> getRecommendationMetadata() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('recommendations')
          .doc('_metadata')
          .get();

      if (!doc.exists) return null;

      return RecommendationMetadata.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('Error fetching recommendation metadata: $e');
      return null;
    }
  }

  /// Check if recommendations are available
  Future<bool> hasRecommendations() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('recommendations')
          .doc('_metadata')
          .get();

      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get recommendation stats
  Future<Map<String, dynamic>> getRecommendationStats() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final metadata = await getRecommendationMetadata();
      final viewHistory = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('viewHistory')
          .count()
          .get();

      final orders = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('order')
          .where('orderStatus', isEqualTo: 'completed')
          .count()
          .get();

      return {
        'hasRecommendations': metadata != null,
        'totalRecommendations': metadata?.totalRecommendations ?? 0,
        'basedOnViews': metadata?.basedOnViews ?? 0,
        'basedOnPurchases': metadata?.basedOnPurchases ?? 0,
        'totalViews': viewHistory.count,
        'totalPurchases': orders.count,
        'lastGenerated': metadata?.generatedAt,
        'version': metadata?.version ?? 'unknown',
      };
    } catch (e) {
      debugPrint('Error getting recommendation stats: $e');
      return {};
    }
  }
}

// Supporting classes
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

// Keep existing model classes
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

class RecommendationMetadata {
  final DateTime generatedAt;
  final int totalRecommendations;
  final int basedOnViews;
  final int basedOnPurchases;
  final String version;

  RecommendationMetadata({
    required this.generatedAt,
    required this.totalRecommendations,
    required this.basedOnViews,
    required this.basedOnPurchases,
    required this.version,
  });

  factory RecommendationMetadata.fromMap(Map<String, dynamic> map) {
    return RecommendationMetadata(
      generatedAt: (map['generatedAt'] as Timestamp).toDate(),
      totalRecommendations: map['totalRecommendations'] ?? 0,
      basedOnViews: map['basedOnViews'] ?? 0,
      basedOnPurchases: map['basedOnPurchases'] ?? 0,
      version: map['version'] ?? '3.0-offline',
    );
  }
}

// Helper class for organizing recommendation reasons
class RecommendationReason {
  final String text;
  final int priority; // 1 = highest priority, 4 = lowest priority
  final double specificity; // Higher number = more specific reason

  RecommendationReason({
    required this.text,
    required this.priority,
    required this.specificity,
  });
}
