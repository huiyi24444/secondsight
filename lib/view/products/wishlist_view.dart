import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:secondsight/model/product_model.dart';
import 'package:secondsight/view/widgets/product_card.dart';
import 'package:secondsight/view/widgets/custom_back_button.dart';

class WishlistView extends StatelessWidget {
  final String userId;
  const WishlistView({Key? key, required this.userId}) : super(key: key);

  Future<List<Product>> _fetchWishlistProducts() async {
    final wishlistSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .get();

    final productRefs = wishlistSnapshot.docs
        .map((doc) => doc['productRef'] as DocumentReference)
        .toList();

    final productSnapshots = await Future.wait(productRefs.map((ref) => ref.get()));

    return productSnapshots
        .where((snap) => snap.exists)
        .map((snap) {
      final data = snap.data() as Map<String, dynamic>;
      return Product.fromDocument(data, snap.id);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text("My Wishlist"),
        leading: const CustomBackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: FutureBuilder<List<Product>>(
          future: _fetchWishlistProducts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("Your wishlist is empty."));
            }

            final products = snapshot.data!;
            return GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 0.60,
              mainAxisSpacing: 5,
              crossAxisSpacing: 1,
              children: products
                  .map((product) => ProductCard(product: product))
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}
