import 'package:cloud_firestore/cloud_firestore.dart';
import '../../model/cart_item_model.dart';
import '../../model/product_model.dart';


class CartController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<CartItem>> fetchCartItems(String userId) async {
    try {
      final cartSnapshot = await _db.collection('users').doc(userId).collection('cart').get();
      List<CartItem> cartItems = [];

      for (final cartDoc in cartSnapshot.docs) {
        final data = cartDoc.data();

        // Safely cast or skip if invalid
        if (data['productID'] is! DocumentReference) {
          print('Invalid productID in cart item: ${data['productID']}');
          continue;
        }

        final productRef = data['productID'] as DocumentReference;
        final productSnap = await productRef.get();

        if (productSnap.exists) {
          final product = Product.fromDocumentSnapshot(productSnap);
          final quantity = (data['cartQuantity'] as num?)?.toInt() ?? 1;
          cartItems.add(CartItem(product: product, quantity: quantity));
        }
      }
      return cartItems;
    } catch (e, stack) {
      print('Error loading cart: $e');
      print(stack);
      return [];
    }
  }

  Future<void> increaseQuantity(String userId, String productId) async {
    final cartRef = _db.collection('users').doc(userId).collection('cart');
    final query = await cartRef.where('productID', isEqualTo: _db.collection('products').doc(productId)).limit(1).get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final currentQty = (doc.data()['cartQuantity'] ?? 1) as int;
      await doc.reference.update({'cartQuantity': currentQty + 1});
    }
  }

  Future<void> decreaseQuantity(String userId, String productId) async {
    final cartRef = _db.collection('users').doc(userId).collection('cart');
    final query = await cartRef.where('productID', isEqualTo: _db.collection('products').doc(productId)).limit(1).get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final currentQty = (doc.data()['cartQuantity'] ?? 1) as int;

      if (currentQty > 1) {
        await doc.reference.update({'cartQuantity': currentQty - 1});
      } else {
        await doc.reference.delete();
      }
    }
  }

  Future<void> removeItem(String userId, String productId) async {
    final cartRef = _db.collection('users').doc(userId).collection('cart');
    final query = await cartRef.where('productID', isEqualTo: _db.collection('products').doc(productId)).limit(1).get();

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.delete();
    }
  }


}
