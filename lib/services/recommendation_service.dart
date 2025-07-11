// personalized_recommendation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PersonalizedRecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Replace with your actual Cloud Function URL
  static const String _cloudFunctionUrl = 'https://batch-update-recommendations-d2z2wc7shq-et.a.run.app';

  // Cache recommendations with better management
  List<PersonalizedRecommendation>? _cachedRecommendations;
  DateTime? _lastFetched;
  bool _isCurrentlyFetching = false; // Prevent multiple simultaneous calls

  /// Get personalized recommendations for current user
  Future<List<PersonalizedRecommendation>> getPersonalizedRecommendations({
    bool forceRefresh = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return [];
    }

    // Prevent multiple simultaneous calls
    if (_isCurrentlyFetching && !forceRefresh) {
      // Wait for current operation to complete
      while (_isCurrentlyFetching) {
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

    _isCurrentlyFetching = true;

    try {
      // First, check if we have recent recommendations
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('recommendations')
          .where('rank', isLessThanOrEqualTo: 20)
          .orderBy('rank')
          .get();

      // Check if recommendations are stale (older than 24 hours)
      bool shouldUpdateRecommendations = false;

      if (snapshot.docs.isNotEmpty) {
        final metadataDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('recommendations')
            .doc('_metadata')
            .get();

        if (metadataDoc.exists) {
          final generatedAt = (metadataDoc.data()!['generatedAt'] as Timestamp).toDate();
          final hoursSinceGeneration = DateTime.now().difference(generatedAt).inHours;

          if (hoursSinceGeneration > 24) {
            shouldUpdateRecommendations = true;
          }
        }
      } else {
        shouldUpdateRecommendations = true;
      }

      // If we need fresh recommendations, call the Cloud Function
      if (shouldUpdateRecommendations) {
        // Generate in background, don't wait for it to complete
        _generateRecommendationsViaAPI(user.uid);

        // Return existing recommendations if available
        if (snapshot.docs.isNotEmpty) {
          final recommendations = snapshot.docs
              .where((doc) => doc.id != '_metadata')
              .map((doc) => PersonalizedRecommendation.fromFirestore(doc))
              .toList();

          _cachedRecommendations = recommendations;
          _lastFetched = DateTime.now();
          return recommendations;
        }

        // Wait for new recommendations if none exist
        await Future.delayed(const Duration(seconds: 3));

        final updatedSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('recommendations')
            .where('rank', isLessThanOrEqualTo: 20)
            .orderBy('rank')
            .get();

        if (updatedSnapshot.docs.isNotEmpty) {
          final recommendations = updatedSnapshot.docs
              .where((doc) => doc.id != '_metadata')
              .map((doc) => PersonalizedRecommendation.fromFirestore(doc))
              .toList();

          _cachedRecommendations = recommendations;
          _lastFetched = DateTime.now();
          return recommendations;
        }
      }

      // Return existing recommendations
      if (snapshot.docs.isNotEmpty) {
        final recommendations = snapshot.docs
            .where((doc) => doc.id != '_metadata')
            .map((doc) => PersonalizedRecommendation.fromFirestore(doc))
            .toList();

        _cachedRecommendations = recommendations;
        _lastFetched = DateTime.now();
        return recommendations;
      }

      return [];
    } catch (e) {
      debugPrint('Error fetching personalized recommendations: $e');
      return _cachedRecommendations ?? [];
    } finally {
      _isCurrentlyFetching = false;
    }
  }

  // Track product view with rate limiting
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
      //await _firestore
      //           .collection('products')
      //           .doc(productId)
      //           .update({
      //         'viewCount': FieldValue.increment(1),
      //       });

      // Throttle recommendation updates - only after 10 views
      final viewHistory = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('viewHistory')
          .orderBy('viewedAt', descending: true)
          .limit(10)
          .get();

      // If user has viewed 10 products recently, refresh recommendations
      if (viewHistory.docs.length >= 10) {
        // Generate in background without waiting
        _generateRecommendationsViaAPI(user.uid);
      }
    } catch (e) {
      debugPrint('Error tracking product view: $e');
    }
  }

  /// Clear cache and force refresh
  void clearCache() {
    _cachedRecommendations = null;
    _lastFetched = null;
  }

  /// Generate recommendations via Cloud Function API
  Future<bool> _generateRecommendationsViaAPI(String userId) async {
    try {
      debugPrint('Calling Cloud Function to generate recommendations for user: $userId');

      final response = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint('Cloud Function response status: ${response.statusCode}');
      debugPrint('Cloud Function response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return true;
        } else {
          debugPrint('Cloud Function returned error: ${responseData['message']}');
          return false;
        }
      } else {
        debugPrint('Cloud Function HTTP error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error calling Cloud Function: $e');
      return false;
    }
  }

  /// Manually trigger recommendation generation (for testing or admin purposes)
  Future<bool> generateRecommendations({bool showProgress = false}) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      if (showProgress) {
        debugPrint('Generating recommendations...');
      }

      final success = await _generateRecommendationsViaAPI(user.uid);

      if (success) {
        // Clear cache to force fresh fetch
        clearCache();

        if (showProgress) {
          debugPrint('Recommendations generated successfully');
        }
        return true;
      } else {
        if (showProgress) {
          debugPrint('Failed to generate recommendations');
        }
        return false;
      }
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



  /// Request recommendation update via API
  Future<void> requestRecommendationUpdate() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _generateRecommendationsViaAPI(user.uid);
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

  /// Get recommendation stats for debugging
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

// Models (keeping the existing ones)
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
      version: map['version'] ?? '2.0',
    );
  }
}