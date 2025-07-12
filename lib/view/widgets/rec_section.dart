// Create a completely fresh recommendations_section.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secondsight/model/product_model.dart';
import 'package:secondsight/view/widgets/product_card.dart';

class RecommendationsSection extends StatefulWidget {
  final String userId;

  const RecommendationsSection({Key? key, required this.userId}) : super(key: key);

  @override
  State<RecommendationsSection> createState() => _RecommendationsSectionState();
}

class _RecommendationsSectionState extends State<RecommendationsSection> {
  Future<List<String>>? _productIdsFuture;
  Future<QuerySnapshot>? _productSnapshotsFuture;

  @override
  void initState() {
    super.initState();
    print('RecommendationsSection initState called');
    _productIdsFuture = _getRecommendedProductIds();
  }

  @override
  void didUpdateWidget(RecommendationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      print('UserId changed, refetching recommendations');
      _productIdsFuture = _getRecommendedProductIds();
    }
  }

  Future<List<String>> _getRecommendedProductIds() async {
    try {
      print('Fetching recommendation IDs for user: ${widget.userId}');

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('recommendations')
          .orderBy('rank')
          .limit(20)
          .get();

      print('Found ${snapshot.docs.length} recommendation documents');

      final List<String> productIds = [];

      for (var doc in snapshot.docs) {
        try {
          final rawData = doc.data();
          Map<String, dynamic> docData;

          if (rawData is Map<String, dynamic>) {
            docData = rawData;
          } else if (rawData is Map<dynamic, dynamic>) {
            docData = {};
            rawData.forEach((key, value) {
              docData[key.toString()] = value;
            });
          } else {
            print('Unexpected data type: ${rawData.runtimeType}');
            continue;
          }

          // Extract the productId field
          final productId = docData['productId'] as String?;

          if (productId != null && productId.isNotEmpty) {
            productIds.add(productId);
            print('Added productId: $productId');
          } else {
            print('ProductId is null or empty for document ${doc.id}');
            print('Available fields: ${docData.keys.toList()}');
          }
        } catch (e) {
          print('Error processing recommendation document ${doc.id}: $e');
          continue;
        }
      }

      print('Final productIds extracted: $productIds');
      print('Total product IDs: ${productIds.length}');
      return productIds;
    } catch (e) {
      print('Error fetching recommendation IDs: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    print('RecommendationsSection build called');

    return FutureBuilder<List<String>>(
      future: _productIdsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Error in recommendations FutureBuilder: ${snapshot.error}');
          return const SizedBox(
            height: 100,
            child: Center(
              child: Text(
                'Error loading recommendations',
                style: TextStyle(fontSize: 14, color: Colors.red),
              ),
            ),
          );
        }

        final productIds = snapshot.data ?? [];

        if (productIds.isEmpty) {
          return const SizedBox(
            height: 100,
            child: Center(
              child: Text(
                'No recommendations yet. Browse more products to get personalized suggestions!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Fetch actual products using the product IDs
        return SizedBox(
          height: 270,
          child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('products')
                .where(FieldPath.documentId, whereIn: productIds.take(10).toList())
                .get(),
            builder: (context, productSnapshot) {
              if (productSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (productSnapshot.hasError) {
                print('Error fetching products: ${productSnapshot.error}');
                return const Center(
                  child: Text(
                    'Error loading products',
                    style: TextStyle(fontSize: 14, color: Colors.red),
                  ),
                );
              }

              final docs = productSnapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No recommended products available',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                itemCount: docs.length,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemBuilder: (context, index) {
                  try {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final product = Product.fromDocument(data, docs[index].id);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: SizedBox(
                        width: 160,
                        child: ProductCard(product: product),
                      ),
                    );
                  } catch (e) {
                    print('Error creating ProductCard at index $index: $e');
                    return Container(width: 160);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}