import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../checkout/cart_view.dart';

class CartIconWithBadge extends StatelessWidget {
  final Color? iconColor;
  final Color? badgeColor;
  final Color? badgeTextColor;
  final double iconSize;
  final bool showBackground;
  final Color? backgroundColor;

  const CartIconWithBadge({
    super.key,
    this.iconColor,
    this.badgeColor,
    this.badgeTextColor,
    this.iconSize = 27,
    this.showBackground = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    print('CartIconWithBadge building at ${DateTime.now()}');
    final userId = Provider.of<AuthProvider>(context).userId;

    return StreamBuilder<QuerySnapshot>(
      stream: userId != null && userId.isNotEmpty
          ? FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart')
          .snapshots()
          : null,
      builder: (context, snapshot) {
        int itemCount = 0;

        if (snapshot.hasData) {
          // Calculate total quantity from all cart items
          for (var doc in snapshot.data!.docs) {
            final quantity = doc.data() as Map<String, dynamic>;
            itemCount += (quantity['cartQuantity'] as int? ?? 1);
          }
        }

        return Container(
          margin: const EdgeInsets.only(right: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background circle (optional)

                IconButton(
                  icon: Icon(
                    Icons.shopping_cart_outlined,
                    size: iconSize,
                  ),
                  color: iconColor ?? Colors.black,
                  onPressed: () => _navigateToCart(context, userId),
                ),

              // Badge
              if (itemCount > 0)
                Positioned(
                  right: showBackground ? -4 : 0,
                  top: showBackground ? -4 : 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: badgeColor ?? Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      itemCount > 99 ? '99+' : itemCount.toString(),
                      style: TextStyle(
                        color: badgeTextColor ?? Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToCart(BuildContext context, String? userId) {
    if (userId != null && userId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CartView(userId: userId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in first.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}