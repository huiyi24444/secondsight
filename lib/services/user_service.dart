// Additional helper function to update Firestore when email is verified
// Add this to your AuthProvider or as a separate service
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Update user verification status in Firestore
  static Future<void> updateEmailVerificationStatus(String userId, bool isVerified) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isVerified': isVerified,
        'emailVerifiedAt': isVerified ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      print('Error updating email verification status: $e');
    }
  }

  // Get user document
  static Future<DocumentSnapshot> getUserDocument(String userId) async {
    return await _firestore.collection('users').doc(userId).get();
  }
}
