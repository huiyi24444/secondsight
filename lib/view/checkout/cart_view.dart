import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:secondsight/view/widgets/order_status_utils.dart';
import '../../controller/checkout/cart_controller.dart';
import '../../model/cart_item_model.dart';
import '../widgets/custom_back_button.dart';
import 'checkout_view.dart';

class CartView extends StatefulWidget {
  final String userId; // pass authenticated userId
  const CartView({super.key, required this.userId});

  @override
  State<CartView> createState() => _CartViewState();
}

class _CartViewState extends State<CartView> {
  final CartController _cartController = CartController();
  late Future<List<CartItem>> _cartItemsFuture;

  @override
  void initState() {
    super.initState();
    _cartItemsFuture = _cartController.fetchCartItems(widget.userId);
  }

  double _calculateSubtotal(List<CartItem> items) {
    // Only calculate subtotal for in-stock items
    return items.where((item) => item.product.stockQuantity > 0)
        .fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  // Check if any items are out of stock
  bool _hasOutOfStockItems(List<CartItem> items) {
    return items.any((item) => item.product.stockQuantity == 0);
  }

  // Add confirmation dialog method
  Future<bool> _showRemoveConfirmation(BuildContext context, String productName) async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Remove Item',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: Text(
            'Are you sure you want to remove "$productName" from your cart?',
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text(
                'Remove',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Light grey background
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text(
          "Cart",
          style: TextStyle(
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFFFAFAFA),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<List<CartItem>>(
        future: _cartItemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Error loading cart',
                style: TextStyle(color: Colors.black54),
              ),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final subtotal = _calculateSubtotal(items);
          const shippingCost = 8.0;
          final total = subtotal + shippingCost;
          final hasOutOfStock = _hasOutOfStockItems(items);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isOutOfStock = item.product.stockQuantity == 0;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOutOfStock ? Colors.grey[100] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Product Image
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: ColorFiltered(
                                            colorFilter: isOutOfStock
                                                ? const ColorFilter.mode(
                                              Colors.grey,
                                              BlendMode.saturation,
                                            )
                                                : const ColorFilter.mode(
                                              Colors.transparent,
                                              BlendMode.multiply,
                                            ),
                                            child: item.product.images.isNotEmpty
                                                ? Image.network(
                                              item.product.images.first,
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            )
                                                : Container(
                                              width: 80,
                                              height: 80,
                                              color: Colors.grey[100],
                                              child: Icon(
                                                Icons.image_not_supported_outlined,
                                                size: 32,
                                                color: Colors.grey[400],
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (isOutOfStock)
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.5),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  'SOLD OUT',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    // Product Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        //name and size and condition
                                        children: [
                                          Text(
                                            item.product.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              letterSpacing: -0.3,
                                              height: 1.3,
                                              color: isOutOfStock ? Colors.grey[600] : Colors.black,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Size ${item.product.productSize} • ${OrderStatusUtils.formatCondition(item.product.condition)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isOutOfStock ? Colors.grey[500] : Colors.grey[600],
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          if (isOutOfStock) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Out of Stock',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],

                                      ),

                                    ),
                                    const SizedBox(width: 10),
                                    // Price (moved to top row)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      //price
                                      children: [

                                        Text(
                                          'RM${item.totalPrice.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            letterSpacing: -0.3,
                                            color: isOutOfStock ? Colors.grey[500] : Colors.black,
                                            decoration: isOutOfStock ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                        if (item.quantity > 1) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'RM${item.product.price.toStringAsFixed(2)} each',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isOutOfStock ? Colors.grey[500] : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                // Bottom section with quantity controls/remove button positioned to the right
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    //qty and remove button
                                    if (!isOutOfStock) ...[
                                      Row(
                                        children: [
                                          _buildQuantityButton(
                                            Icons.remove,
                                                () async {
                                              if (item.quantity > 1) {
                                                await _cartController.decreaseQuantity(widget.userId, item.product.id);
                                                setState(() {
                                                  _cartItemsFuture = _cartController.fetchCartItems(widget.userId);
                                                });
                                              } else {
                                                // Show confirmation dialog before removing
                                                final shouldRemove = await _showRemoveConfirmation(
                                                  context,
                                                  item.product.name,
                                                );
                                                if (shouldRemove) {
                                                  await _cartController.removeItem(widget.userId, item.product.id);
                                                  setState(() {
                                                    _cartItemsFuture = _cartController.fetchCartItems(widget.userId);
                                                  });
                                                  // Show snackbar after successful removal
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('${item.product.name} removed from cart'),
                                                        behavior: SnackBarBehavior.floating,
                                                        duration: const Duration(seconds: 2),
                                                        action: SnackBarAction(
                                                          label: 'OK',
                                                          onPressed: () {},
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            },
                                          ),
                                          Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Text(
                                              item.quantity.toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          _buildQuantityButton(
                                            Icons.add,
                                                () async {
                                              if (item.quantity < item.product.stockQuantity) {
                                                await _cartController.increaseQuantity(widget.userId, item.product.id);
                                                setState(() {
                                                  _cartItemsFuture = _cartController.fetchCartItems(widget.userId);
                                                });
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Maximum stock reached'),
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      TextButton.icon(
                                        onPressed: () async {
                                          final shouldRemove = await _showRemoveConfirmation(
                                            context,
                                            item.product.name,
                                          );
                                          if (shouldRemove) {
                                            await _cartController.removeItem(widget.userId, item.product.id);
                                            setState(() {
                                              _cartItemsFuture = _cartController.fetchCartItems(widget.userId);
                                            });
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('${item.product.name} removed from cart'),
                                                  behavior: SnackBarBehavior.floating,
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.delete_outline, size: 18),
                                        label: const Text('Remove'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Summary Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (hasOutOfStock) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Remove out of stock items to proceed',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange[900],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildSummaryRow('Subtotal', subtotal),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Shipping', shippingCost),
                        const SizedBox(height: 8),
                        Container(
                          height: 1,
                          color: Colors.grey[200],
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryRow('Total', total, isTotal: true),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: hasOutOfStock ? null : () async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) return;

                              // Fetch cart items from Firestore
                              final cartItems = await CartController().fetchCartItems(user.uid);

                              // Filter out out-of-stock items
                              final inStockItems = cartItems.where((item) => item.product.stockQuantity > 0).toList();

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CheckoutView(
                                    subtotal: subtotal,
                                    shippingCost: shippingCost,
                                    total: total,
                                    cartItems: inStockItems,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasOutOfStock ? Colors.grey[400] : const Color(0xFF8E6CEF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                            child: const Text(
                              'Proceed to Checkout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? Colors.black87 : Colors.grey[700],
            letterSpacing: -0.3,
          ),
        ),
        Text(
          'RM${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: Colors.black87,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}