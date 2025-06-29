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

  const ProductView({Key? key, this.categoryRef, this.isNewIn = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final productStream = isNewIn
        ? FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        : categoryRef == null
        ? FirebaseFirestore.instance.collection('products').snapshots()
        : FirebaseFirestore.instance
        .collection('products')
        .where('category', isEqualTo: categoryRef)
        .snapshots();

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
            // Show category title
            if (categoryRef != null && !isNewIn)
          FutureBuilder<DocumentSnapshot>(
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

        final data = snapshot.data!.data() as Map<String, dynamic>;
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
              child: StreamBuilder<QuerySnapshot>(
                stream: productStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  return GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 0.60,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 1,
                    children:
                        docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final product = Product.fromDocument(data, doc.id);
                          return ProductCard(product: product);
                        }).toList(),
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
