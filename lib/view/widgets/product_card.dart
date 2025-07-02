import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondsight/model/product_model.dart';
import 'package:secondsight/view/products/product_details_view.dart';

import '../../services/auth_provider.dart'; // Adjust path if needed

class ProductCard extends StatefulWidget {
  final Product product;

  const ProductCard({Key? key, required this.product}) : super(key: key);

  @override
  _ProductCardState createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.product.images.isNotEmpty
        ? widget.product.images.first
        : 'https://picsum.photos/200';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsView(productId: widget.product.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Image section
            Expanded(
              flex: 7,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: SizedBox.expand(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () async {
                        setState(() {
                          isFavorite = !isFavorite;
                        });

                        final userId = Provider.of<AuthProvider>(context, listen: false).userId;

                        if (userId == null || userId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('You need to be logged in to add to wishlist')),
                          );
                          return;
                        }

                        final wishlistRef = FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .collection('wishlist');

                        final productRef = FirebaseFirestore.instance
                            .collection('products')
                            .doc(widget.product.id);

                        try {
                          if (isFavorite) {
                            // Add to wishlist
                            await wishlistRef.doc(widget.product.id).set({
                              'productRef': productRef,
                              'addedAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            // Remove from wishlist
                            await wishlistRef.doc(widget.product.id).delete();
                          }
                        } catch (e) {
                          print('Error updating wishlist: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error updating wishlist')),
                          );
                        }
                      },

                      child: CircleAvatar(
                        radius: 14, // smaller than the default (~20)
                        backgroundColor: Colors.white70,
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 16, // smaller icon
                          color: isFavorite ? Colors.red : Colors.grey,
                        ),
                      ),

                    ),
                  ),
                ],
              ),
            ),

            // Text section
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'RM ${widget.product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'RM ${widget.product.oriPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.product.condition,
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
