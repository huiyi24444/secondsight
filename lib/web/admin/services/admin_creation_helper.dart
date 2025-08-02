// admin_creation_helper.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCreationHelper {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new admin user with email verification
  static Future<void> createAdminWithVerification({
    required String email,
    required String password,
    required String name,
    required String role,
    required List<String> permissions,
  }) async {
    try {
      // Create the user account
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = credential.user;
      if (user == null) throw Exception('Failed to create user');

      // Send verification email immediately
      await user.sendEmailVerification();
      print('Verification email sent to $email');

      // Create admin document in Firestore
      await _firestore.collection('admins').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'name': name,
        'role': role,
        'permissions': permissions,
        'isActive': true,
        'isVerified': false, // Will be updated when email is verified
        'createdAt': FieldValue.serverTimestamp(),
        'verifiedAt': null, // Will be updated when email is verified
      });

      print('Admin created successfully. Verification email sent.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        print('Email already in use. Trying to send verification to existing user...');

        // If user already exists, try to send verification email
        User? currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.email == email && !currentUser.emailVerified) {
          await currentUser.sendEmailVerification();
          print('Verification email sent to existing user');
        }
      }
      throw e;
    }
  }

  /// Manually trigger verification email for existing admin
  static Future<void> sendVerificationToExistingAdmin(String email, String password) async {
    try {
      // Sign in temporarily to send verification
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = credential.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        print('Verification email sent to $email');

        // Sign out after sending email
        await _auth.signOut();
        return;
      } else if (user != null && user.emailVerified) {
        print('Email is already verified');
        await _auth.signOut();
        return;
      }
    } catch (e) {
      print('Error sending verification: $e');
      throw e;
    }
  }

  /// Update admin verification status in Firestore
  static Future<void> updateAdminVerificationStatus(String uid) async {
    try {
      await _firestore.collection('admins').doc(uid).update({
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating verification status: $e');
    }
  }
}