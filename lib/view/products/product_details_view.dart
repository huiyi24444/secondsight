import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/product_measurements_model.dart';
import '../../model/product_model.dart';
import '../../features/virtual_try_on/screens/virtual_try_on_screen.dart';
import '../../services/auth_provider.dart';
import '../checkout/cart_view.dart';
import '../widgets/string_extensions.dart';

class ProductDetailsView extends StatefulWidget {
  final String productId;

  const ProductDetailsView({super.key, required this.productId});

  @override
  State<ProductDetailsView> createState() => _ProductDetailsViewState();
}

class _ProductDetailsViewState extends State<ProductDetailsView> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context).userId;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('products').doc(widget.productId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF8E6CEF),
              ),
            ),
          );
        }

        // Convert to Product model
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final product = Product.fromDocument(data, widget.productId);
        print('Measurements in Product model: ${product.measurements}');



        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {},
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Product Images with Indicator
                Stack(
                  children: [
                    SizedBox(
                      height: 400,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemCount: product.images.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                product.images[index],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Image counter badge
                    Positioned(
                      right: 24,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1} / ${product.images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Image dots indicator
                if (product.images.length > 1)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        product.images.length,
                            (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentImageIndex == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentImageIndex == index
                                ? const Color(0xFF8E6CEF)
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Price with discount badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'RM ${product.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              color: Color(0xFF8E6CEF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'RM ${product.oriPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '-${((1 - product.price / product.oriPrice) * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Enhanced Size & Condition Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoBox(
                              label: capitalizeEachWord(product.condition),
                              conditionColor: _getConditionColor(product.condition),
                              isCondition: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoBox(
                              label:'Size ${product.productSize}',
                              conditionColor: null,
                              isCondition: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),


                      // Enhanced Try On Button
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: product.hasVirtualTryOn
                              ? const LinearGradient(
                            colors: [Color(0xFF8E6CEF), Color(0xFFA78BFA)],
                          )
                              : null,
                          color: product.hasVirtualTryOn ? null : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: product.hasVirtualTryOn
                              ? [
                            BoxShadow(
                              color: const Color(0xFF8E6CEF).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                              : null,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: product.hasVirtualTryOn
                              ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VirtualTryOnScreen(
                                  productId: widget.productId,
                                  product: product,
                                ),
                              ),
                            );
                          }
                              : null,
                          icon: Icon(
                            product.hasVirtualTryOn ? Icons.camera_alt : Icons.camera_alt_outlined,
                            color: product.hasVirtualTryOn ? Colors.white : Colors.grey[600],
                          ),
                          label: Text(
                            product.hasVirtualTryOn
                                ? "Try On Virtually"
                                : "Virtual Try-On Not Available",
                            style: TextStyle(
                              color: product.hasVirtualTryOn ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                      ),

                      const SizedBox(height: 20),
                      _buildExpandableSection(
                          title: 'Tags',
                          child:   Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: product.tags!.map((tag) {
                              return _buildStyledTag(tag);
                            }).toList(),
                          ),
                      ),
                      _buildExpandableSection(
                        title: 'Details',
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0), // Small spacing around the text
                          child: Align(
                            alignment: Alignment.centerLeft, // Align text to the left
                            child: Text(
                              product.description,
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                      ),



                      _buildExpandableSection(
                          title: 'Measurements',
                          child: _buildMeasurementsTable(product.measurements)

                      ),

                      const SizedBox(height: 20),
                    ],


                  ),
                ),
                // Fixed Bottom Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (userId == null || userId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please log in first.')),
                            );
                            return;
                          }

                          final cartRef = FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .collection('cart');

                          final existingCart = await cartRef
                              .where('productID',
                              isEqualTo: FirebaseFirestore.instance
                                  .collection('products')
                                  .doc(widget.productId))
                              .limit(1)
                              .get();

                          if (existingCart.docs.isNotEmpty) {
                            final existingDoc = existingCart.docs.first;
                            await existingDoc.reference.update({
                              'cartQuantity': (existingDoc.data()['cartQuantity'] ?? 1) + 1,
                            });
                          } else {
                            await cartRef.add({
                              'productID': FirebaseFirestore.instance
                                  .collection('products')
                                  .doc(widget.productId),
                              'cartQuantity': 1,
                            });
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Added to cart!'),
                              duration: Duration(seconds: 2),
                            ),
                          );

                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CartView(userId: userId)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B61FF),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Add to Bag',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMeasurementsTable(ProductMeasurements measurements) {
    // Check if all fields are null
    final allNull = [
      measurements.bust,
      measurements.waist,
      measurements.hip,
      measurements.shoulderWidth,
      measurements.sleeveLength,
      measurements.shirtLength,
      measurements.inseam,
      measurements.outseam,
      measurements.totalLength,
    ].every((value) => value == null);

    if (allNull) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Measurements not available',
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
        ),
      );
    }

    // Helper function to build rows
    TableRow buildRow(String label, double? value) {
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(label),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(value != null ? '${value.toStringAsFixed(1)} cm' : '-'),
          ),
        ],
      );
    }

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        if (measurements.bust != null) buildRow('Bust', measurements.bust),
        if (measurements.waist != null) buildRow('Waist', measurements.waist),
        if (measurements.hip != null) buildRow('Hip', measurements.hip),
        if (measurements.shoulderWidth != null) buildRow('Shoulder Width', measurements.shoulderWidth),
        if (measurements.sleeveLength != null) buildRow('Sleeve Length', measurements.sleeveLength),
        if (measurements.shirtLength != null) buildRow('Shirt Length', measurements.shirtLength),
        if (measurements.inseam != null) buildRow('Inseam', measurements.inseam),
        if (measurements.outseam != null) buildRow('Outseam', measurements.outseam),
        if (measurements.totalLength != null) buildRow('Total Length', measurements.totalLength),
      ],
    );
  }



  Widget _buildStyledTag(String tag) {
    // Determine tag style based on content
    Color bgColor = Colors.grey[100]!;
    Color textColor = Colors.grey[700]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: textColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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


  Color _getConditionColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'new':
      case 'brand new':
        return Colors.green;
      case 'like new':
      case 'excellent':
        return Colors.lightGreen;
      case 'good':
      case 'very good':
        return Colors.orange;
      case 'fair':
      case 'used':
        return Colors.amber;
      case 'poor':
      case 'damaged':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoBox({
    required String label,
    required Color? conditionColor,
    required bool isCondition,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Color indicator circle (only for condition box)
          if (isCondition && conditionColor != null) ...[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: conditionColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

}
