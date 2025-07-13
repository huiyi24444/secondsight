import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../model/product_model.dart';
import '../widgets/product_small_card.dart';

class SimilarProductsSection extends StatelessWidget {
  final DocumentReference categoryRef;
  final String currentProductId;
  final int limit;

  const SimilarProductsSection({
    Key? key,
    required this.categoryRef,
    required this.currentProductId, // To exclude the current product from the results
    this.limit = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('SimilarProductsSection building at ${DateTime.now()}');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('category', isEqualTo: categoryRef)
          .limit(limit)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8E6CEF)),
            ),
          );
        }

        final docs = snapshot.data!.docs
            .where((doc) => doc.id != currentProductId) // Exclude current product
            .toList();

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'No similar products found',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        final products = docs.map((doc) => Product.fromDocumentSnapshot(doc)).toList();

        return SizedBox(
          height: 270,
          child: ListView.builder(
            itemCount: products.length,
            scrollDirection: Axis.horizontal,
            addAutomaticKeepAlives: true,
            addRepaintBoundaries: true,
            cacheExtent: 500.0,
            itemBuilder: (context, index) {
              final product = products[index];
              final createdAt = product.createdAt is Timestamp
                  ? (product.createdAt as Timestamp).toDate()
                  : product.createdAt as DateTime?;

              final daysSinceCreation = DateTime.now()
                  .difference(createdAt ?? DateTime.now())
                  .inDays;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: SizedBox(
                  width: 160,
                  child: Stack(
                    children: [
                      ProductSmallCard(
                        key: ValueKey(product.id),
                        product: product,
                      ),
                      if (daysSinceCreation <= 7)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            // You can style your "NEW" badge here
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
