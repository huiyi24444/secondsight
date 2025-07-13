import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/model/product_model.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:secondsight/view/widgets/custom_back_button.dart';
import 'package:secondsight/view/widgets/product_card.dart';

// Main screen
class ProductView extends StatelessWidget {
  final DocumentReference? categoryRef;
  final bool isNewIn;
  final bool isRecommendations; // Add this flag
  final List<String>? recommendedProductIds; // Add this for product IDs

  const ProductView({
    Key? key,
    this.categoryRef,
    this.isNewIn = false,
    this.isRecommendations = false,
    this.recommendedProductIds,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Stream<QuerySnapshot> productStream;

    if (isRecommendations && recommendedProductIds != null) {
      // For recommendations, get products by their IDs
      productStream = FirebaseFirestore.instance
          .collection('products')
          .where(FieldPath.documentId, whereIn: recommendedProductIds)
          .snapshots();
    } else if (isNewIn) {
      // For New In products
      productStream = FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else if (categoryRef != null) {
      // For category products
      productStream = FirebaseFirestore.instance
          .collection('products')
          .where('category', isEqualTo: categoryRef)
          .snapshots();
    } else {
      // For all products
      productStream = FirebaseFirestore.instance.collection('products').snapshots();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: const CustomBackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.only(
          top: 0.0,
          left: 14.0,
          right: 14.0,
          bottom: 14.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show title based on view type
            if (isRecommendations)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Recommended for You',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isNewIn)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'New In',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (categoryRef != null && !isNewIn && !isRecommendations)
              FutureBuilder(
                future: categoryRef!.get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Category'),
                    );
                  }

                  final data = snapshot.data!.data() as Map;
                  final categoryName = data['catName'] ?? 'Category';

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      categoryName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),

            // Products Grid
            Expanded(
              child: StreamBuilder(
                stream: productStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No products found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.60, // Adjusted to match the 3:4 image ratio plus text space
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final product = Product.fromDocument(data, doc.id);
                      return ProductCard(
                        key: ValueKey(product.id),
                        product: product,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}