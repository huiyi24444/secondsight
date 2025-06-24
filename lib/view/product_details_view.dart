import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProductDetailsView extends StatelessWidget {
  final String productId;

  const ProductDetailsView({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data() as Map<String, dynamic>;

        final images = List<String>.from(data['productURL'] ?? []);
        final name = data['productName'] ?? 'No name';
        final price = data['productPrice']?.toDouble() ?? 0.0;
        final oriPrice = data['productOriPrice']?.toDouble() ?? 0.0;
        final condition = data['productCondition'] ?? 'Unknown';
        final size = data['measurements.productSize'] ?? 'Unknown';
        final description = data['productDesc'] ?? '';
        //final tags = List<String>.from(data['tags'] ?? []);
        //final composition = data['composition'] ?? '';
        //final shipping = data['shipping'] ?? '';

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () {},
              )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Images
                SizedBox(
                  height: 300,
                  child: PageView(
                    children: images
                        .map((url) => Image.network(url, fit: BoxFit.cover))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Product Name
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),

                // Price
                Row(
                  children: [
                    Text(
                      'RM ${price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, color: Colors.purple, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'RM ${oriPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey, decoration: TextDecoration.lineThrough),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Size & Condition
                Row(
                  children: [
                    _buildTag(context, condition),
                    const SizedBox(width: 10),
                    _buildTag(context, 'Size: $size'),
                  ],
                ),

                const SizedBox(height: 16),

                // Try On Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      print("🟢 Button tapped");
                      //Navigator.push(
                      //                         context,
                      //                         MaterialPageRoute(builder: (_) => const TryOnCameraPage()),
                      //                       );
                    },
                    child: const Text("Try On Virtually"),
                  ),


                ),

                const SizedBox(height: 20),

                _buildExpandableSection(title: 'Details', child: Text(description)),
                _buildExpandableSection(title: 'Tags', child: Wrap(
                  spacing: 8,
                  //children: tags.map((tag) => Chip(label: Text(tag))).toList(),
                )),
                //_buildExpandableSection(title: 'Composition and care', child: Text(composition)),
                //_buildExpandableSection(title: 'Shipping and return policies', child: Text(shipping)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTag(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _buildExpandableSection({required String title, required Widget child}) {
    return Theme(
      data: ThemeData().copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [Padding(padding: const EdgeInsets.all(8), child: child)],
      ),
    );
  }
}
