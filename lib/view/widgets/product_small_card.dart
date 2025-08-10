import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:secondsight/model/product_model.dart';
import 'package:secondsight/view/products/product_details_view.dart';
import '../../services/CustomCacheManager.dart';
import '../../services/auth_provider.dart';

class ProductSmallCard extends StatefulWidget {
  final Product product;

  const ProductSmallCard({Key? key, required this.product}) : super(key: key);

  @override
  _ProductSmallCardState createState() => _ProductSmallCardState();
}

class _ProductSmallCardState extends State<ProductSmallCard> with AutomaticKeepAliveClientMixin {
  // This will keep the widget alive when scrolling
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required when using AutomaticKeepAliveClientMixin

    final userId = Provider.of<AuthProvider>(context).userId;
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
              flex: 10,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Color(0xFFD1D3D0),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        // This ensures the image covers the container while maintaining aspect ratio
                        alignment: Alignment.center,
                        // Memory cache configuration
                        memCacheWidth: 300, // Optimize memory usage
                        memCacheHeight: 400, // Increased height for vertical images
                        cacheManager: CustomCacheManager.instance,
                        // Placeholder while loading
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8E6CEF)),
                            ),
                          ),
                        ),
                        // Error widget
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 30,
                            color: Colors.grey,
                          ),
                        ),
                        // Fade in animation when image loads
                        fadeInDuration: const Duration(milliseconds: 200),
                        fadeOutDuration: const Duration(milliseconds: 100),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: userId != null
                          ? FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('wishlist')
                          .doc(widget.product.id)
                          .snapshots()
                          : null,
                      builder: (context, snapshot) {
                        final isFavorite = snapshot.hasData && snapshot.data!.exists;

                        return GestureDetector(
                          onTap: () async {
                            if (userId == null || userId.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please log in first.'),
                                ),
                              );
                              return;
                            }

                            final favRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .collection('wishlist')
                                .doc(widget.product.id);

                            try {
                              if (isFavorite) {
                                // Remove from favorites
                                await favRef.delete();
                              } else {
                                // Add to favorites
                                await favRef.set({
                                  'productRef': FirebaseFirestore.instance
                                      .collection('products')
                                      .doc(widget.product.id),
                                  'addedAt': FieldValue.serverTimestamp(),
                                });
                              }
                            } catch (e) {
                              print('Error updating wishlist: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Error updating wishlist'),
                                ),
                              );
                            }
                          },
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.white70,
                            child: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: isFavorite ? Colors.red : Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Text section
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
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
                    //const SizedBox(height: 2),
                    //                     Text(
                    //                       widget.product.condition,
                    //                       style: const TextStyle(fontSize: 11, color: Colors.black87),
                    //                       maxLines: 1,
                    //                       overflow: TextOverflow.ellipsis,
                    //                     ),
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