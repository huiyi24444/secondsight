import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secondsight/model/product_model.dart';
import 'package:secondsight/view/widgets/product_card.dart';
import 'package:secondsight/view/widgets/product_small_card.dart';

// Alternative: Horizontal scrolling version for homepage
class NewProductsHorizontalSection extends StatelessWidget {
  final int limit;

  const NewProductsHorizontalSection({
    Key? key,
    this.limit = 10,
  }) : super(key: key);

  List<Product> _filterAvailableProducts(List<Product> products) {
    return products.where((product) {
      final status = product.status?.toLowerCase();

      // Filter out unwanted statuses
      final isAvailable = status != null &&
          status == 'available';

      return isAvailable;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    print('NewProductsHorizontalSection building at ${DateTime.now()}');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(limit * 2)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8E6CEF)),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'No new products available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          );
        }
        // Convert to products and filter by status
        final allProducts = docs.map((doc) => Product.fromDocumentSnapshot(doc)).toList();
        final availableProducts = _filterAvailableProducts(allProducts);

        // Take only the requested limit after filtering
        final products = availableProducts.take(limit).toList();

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
              // Show creation date for first few items (optional)
              final product = products[index];
              final createdAt = product.createdAt is Timestamp
                  ? (product.createdAt as Timestamp).toDate()
                  : product.createdAt as DateTime?;

              final daysSinceCreation = DateTime.now().difference(
                createdAt ?? DateTime.now(),
              ).inDays;
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
                      // Optional: Show "NEW" badge for products less than 7 days old
                      if (daysSinceCreation <= 7)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
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