import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secondsight/model/product_model.dart';
import 'package:secondsight/view/widgets/product_card.dart';
import 'package:secondsight/view/widgets/product_small_card.dart';

// Horizontal scrolling section for products with Virtual Try-On enabled
class VirtualTryOnProductsSection extends StatelessWidget {
  final int limit;

  const VirtualTryOnProductsSection({
    Key? key,
    this.limit = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('DEBUG: VirtualTryOnProductsSection build started at ${DateTime.now()} with limit=$limit');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('virtualTryOn.enabled', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots(),
      builder: (context, snapshot) {
        print('DEBUG: StreamBuilder triggered at ${DateTime.now()} - connectionState=${snapshot.connectionState}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('DEBUG: Waiting for data from Firestore...');
        }

        if (snapshot.hasError) {
          print('ERROR: Firestore query failed - ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          print('DEBUG: No snapshot data yet - showing loading spinner');
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8E6CEF)),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        print('DEBUG: Received ${docs.length} product documents from Firestore');

        if (docs.isEmpty) {
          print('DEBUG: Query returned empty result set');
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'No Virtual Try-On products available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
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
            // Performance optimizations
            addAutomaticKeepAlives: true,
            addRepaintBoundaries: true,
            cacheExtent: 500.0,
            itemBuilder: (context, index) {
              final product = products[index];

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
                      // Virtual Try-On badge
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