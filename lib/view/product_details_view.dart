import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../model/product_model.dart'; // Add this import
import '../features/virtual_try_on/screens/virtual_try_on_screen.dart'; // Add this import

class ProductDetailsView extends StatelessWidget {
  final String productId;

  const ProductDetailsView({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        // Convert to Product model
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final product = Product.fromDocument(data, productId);

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
                    children: product.images
                        .map((url) => Image.network(url, fit: BoxFit.cover))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Product Name
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),

                // Price
                Row(
                  children: [
                    Text(
                      'RM ${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.purple,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'RM ${product.oriPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Size & Condition
                Row(
                  children: [
                    _buildTag(context, product.condition),
                    const SizedBox(width: 10),
                    _buildTag(context, 'Size: ${product.measurements['productSize'] ?? 'Unknown'}'),
                  ],
                ),
                const SizedBox(height: 16),

                // Try On Button - Updated with actual navigation
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: product.hasVirtualTryOn ? () {
                      print("🟢 Navigating to Virtual Try-On");
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VirtualTryOnScreen(
                            productId: productId,
                            product: product, // Pass the product object
                          ),
                        ),
                      );
                    } : null, // Disable if no virtual try-on available
                    icon: const Icon(Icons.camera_alt),
                    label: Text(
                        product.hasVirtualTryOn
                            ? "Try On Virtually"
                            : "Virtual Try-On Not Available"
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: product.hasVirtualTryOn
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                  ),
                ),

                // Add to Bag button
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // Add to cart logic
                    },
                    child: const Text("Add to Bag"),
                  ),
                ),

                const SizedBox(height: 20),
                _buildExpandableSection(
                    title: 'Details',
                    child: Text(product.description)
                ),
                _buildExpandableSection(
                    title: 'Measurements',
                    child: _buildMeasurementsTable(product.measurements)
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMeasurementsTable(Map<String, dynamic> measurements) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      children: measurements.entries.map((entry) {
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(entry.key),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(entry.value.toString()),
            ),
          ],
        );
      }).toList(),
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