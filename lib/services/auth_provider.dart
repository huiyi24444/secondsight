// auth_provider.dart - Updated with email verification methods
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get user => _user;

  String? get userId => _user?.uid;

  bool get isAuthenticated => _user != null;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  bool get isEmailVerified => _user?.emailVerified ?? false;

  AuthProvider() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = credential.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      if (e.code == 'user-not-found') {
        _errorMessage = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        _errorMessage = 'Wrong password provided.';
      } else if (e.code == 'invalid-email') {
        _errorMessage = 'Invalid email address.';
      } else if (e.code == 'user-disabled') {
        _errorMessage = 'This user has been disabled.';
      } else {
        _errorMessage = 'Login failed. Please try again.';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred.';
      notifyListeners();
      return false;
    }
  }

  // Register with email and password
  Future<bool> register(String email, String password,
      String displayName) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      if (credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
        await credential.user!.reload();
        _user = _auth.currentUser;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      if (e.code == 'weak-password') {
        _errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        _errorMessage = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        _errorMessage = 'Invalid email address.';
      } else {
        _errorMessage = 'Registration failed. Please try again.';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred.';
      notifyListeners();
      return false;
    }
  }

  // Send password reset email
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.sendPasswordResetEmail(email: email);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      if (e.code == 'invalid-email') {
        _errorMessage = 'Invalid email address.';
      } else if (e.code == 'user-not-found') {
        _errorMessage = 'No user found for that email.';
      } else {
        _errorMessage = 'Failed to send reset email. Please try again.';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred.';
      notifyListeners();
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to sign out. Please try again.';
      notifyListeners();
    }
  }

  // Update user profile
  Future<bool> updateProfile({String? displayName, String? photoURL}) async {
    try {
      if (_user == null) return false;

      if (displayName != null) {
        await _user!.updateDisplayName(displayName);
      }

      if (photoURL != null) {
        await _user!.updatePhotoURL(photoURL);
      }

      await _user!.reload();
      _user = _auth.currentUser;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update profile.';
      notifyListeners();
      return false;
    }
  }

  // Send email verification
  Future<bool> sendEmailVerification() async {
    try {
      if (_user != null && !_user!.emailVerified) {
        await _user!.sendEmailVerification();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        _errorMessage = 'Too many requests. Please try again later.';
      } else {
        _errorMessage = 'Failed to send verification email.';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send verification email.';
      notifyListeners();
      return false;
    }
  }

  // Check if email is verified
  Future<bool> checkEmailVerification() async {
    try {
      if (_user != null) {
        await _user!.reload();
        _user = _auth.currentUser;
        notifyListeners();
        return _user?.emailVerified ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}