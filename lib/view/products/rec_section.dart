import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secondsight/model/product_model.dart';
import 'package:secondsight/view/widgets/product_card.dart';
import 'package:secondsight/view/widgets/product_small_card.dart';

class RecommendationsSection extends StatefulWidget {
  final String userId;
  final bool showDebugInfo; // Add this parameter to control debug visibility

  const RecommendationsSection({
    Key? key,
    required this.userId,
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

  Future<List<String>> _getRecommendedProductIds() async {
    print('Fetching recommendation IDs for user: ${widget.userId}');
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('recommendations')
          .orderBy('rank')
          .limit(10)
          .get();

      print('Found ${snapshot.docs.length} recommendation docs');

      for (final doc in snapshot.docs) {
        print('Rec doc: ${doc.id} → ${doc.data()}');
      }

      final productIds = snapshot.docs
          .map((doc) => doc.data()['productId'] as String?)
          .where((id) => id != null && id!.isNotEmpty)
          .map((id) => id!)
          .toList();

      print('Extracted product IDs: $productIds');
      return productIds;
    } catch (e) {
      print('Error fetching recommendation IDs: $e');
      return [];
    }
  }


  Future<List<Product>> _getRecommendedProducts() async {
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

    if (rankedProductIds.isEmpty) return [];

    final productSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where(FieldPath.documentId, whereIn: rankedProductIds)
        .get();

    final productMap = {
      for (var doc in productSnapshot.docs)
        doc.id: Product.fromDocument(doc.data(), doc.id),
    };

    return rankedProductIds
        .where((id) => productMap.containsKey(id))
        .map((id) => productMap[id]!)
        .toList();
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
              return const SizedBox(
                height: 270,
                child: Center(child: Text('Error loading recommendations')),
              );
            }

            final products = snapshot.data ?? [];

            if (products.isEmpty) {
              return const SizedBox(
                height: 80,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'No recommended products available',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Check back later or explore more items',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),

                    ],
                  ),
                ),
              );
            }

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