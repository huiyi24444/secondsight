// admin_auth_provider.dart - UPDATED VERSION
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../model/admin_log_model.dart';
import '../../../model/admin_model.dart';
import '../login/admin_session_service.dart';

class AdminAuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAdmin = false;
  Map<String, dynamic>? _adminData;
  bool _isFirestoreVerified = false; // NEW: Track Firestore verification status

  // Getters
  User? get user => _user;
  String? get userId => _user?.uid;
  bool get isAuthenticated => _user != null && _isAdmin;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAdmin => _isAdmin;
  Map<String, dynamic>? get adminData => _adminData;
  String? get adminName => _adminData?['name'] ?? _user?.displayName;
  String? get adminRole => _adminData?['role'];

  // UPDATED: Check both Firebase Auth and Firestore verification
  bool get isEmailVerified => (_user?.emailVerified ?? false) || _isFirestoreVerified;

  AdminAuthProvider() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) async {
      _user = user;

      if (user != null) {
        // Check if user is admin whenever auth state changes
        await _checkAdminStatus();
      } else {
        _isAdmin = false;
        _adminData = null;
        _isFirestoreVerified = false;
      }
      notifyListeners();
    });
  }



  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  //check if user is an admin
  Future<void> _checkAdminStatus() async {
    if (_user == null) {
      _isAdmin = false;
      _adminData = null;
      _isFirestoreVerified = false;
      return;
    }

    try {
      final adminDoc = await _firestore
          .collection('admins')
          .doc(_user!.uid)
          .get();

      if (adminDoc.exists) {
        _isAdmin = true;
        _adminData = adminDoc.data();
        _isFirestoreVerified = _adminData?['isVerified'] ?? false;

        // SET UP ADMIN SESSION for logging
        AdminSessionService.instance.setCurrentAdmin(
          AdminModel(
            id: _user!.uid,
            email: _adminData?['email'] ?? _user!.email ?? '',
            name: _adminData?['name'] ?? _user!.displayName ?? '',
            role: _adminData?['role'] ?? 'viewer',
            isAdmin: _adminData?['isAdmin'] ?? false,
            isVerified: _adminData?['isVerified'] ?? false,
            isEnabled: _adminData?['isEnabled'] ?? true,
            permissions: List<String>.from(_adminData?['permissions'] ?? []),
            createdAt: (_adminData?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ),
        );


        // Update last login timestamp
        await _firestore
            .collection('admins')
            .doc(_user!.uid)
            .update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        _isAdmin = false;
        _adminData = null;
        _isFirestoreVerified = false;
      }
    } catch (e) {
      print('Error checking admin status: $e');
      _isAdmin = false;
      _adminData = null;
      _isFirestoreVerified = false;
    }
  }

  // NEW: Method to sync Firebase Auth verification with Firestore
  Future<void> syncVerificationStatus() async {
    if (_user == null || !_isAdmin) return;

    try {
      // If Firebase Auth email is verified but Firestore isn't updated
      if (_user!.emailVerified && !_isFirestoreVerified) {
        await _firestore
            .collection('admins')
            .doc(_user!.uid)
            .update({
          'isVerified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });

        _isFirestoreVerified = true;
        notifyListeners();
      }
      // If Firestore says verified but Firebase Auth doesn't
      else if (_isFirestoreVerified && !_user!.emailVerified) {
        // In this case, trust Firestore (admin might have been manually verified)
        print('Admin is verified in Firestore but not in Firebase Auth. Trusting Firestore.');
      }
    } catch (e) {
      print('Error syncing verification status: $e');
    }
  }

  // Method to check verification status with reload
  Future<bool> checkEmailVerificationStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload(); // Refresh user data from Firebase

      // Check both Firebase Auth and Firestore
      final firebaseVerified = user.emailVerified;

      if (firebaseVerified && !_isFirestoreVerified) {
        // Sync to Firestore if Firebase is verified
        await syncVerificationStatus();
      }

      return firebaseVerified || _isFirestoreVerified;
    }
    return _isFirestoreVerified;
  }

  Future<void> refreshUserStatus() async {
    if (_user != null) {
      await _user!.reload();
      _user = _auth.currentUser;
      await _checkAdminStatus(); // This will also check Firestore verification
      await syncVerificationStatus(); // Sync verification statuses
      notifyListeners();
    }
  }

  // Send email verification
  Future<bool> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send verification email: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = credential.user;

      // Check if the user is an admin first
      await _checkAdminStatus();

      if (!_isAdmin) {
        // LOG FAILED LOGIN - Not an admin
        await AdminActivityLogger.logLogin(
          adminId: _user?.uid ?? 'unknown',
          adminEmail: email,
          adminName: 'Non-admin user',
          adminRole: 'none',
          isSuccessful: false,
          errorMessage: 'Access denied - not an admin',
        );

        // If not an admin, sign out immediately
        await _auth.signOut();
        _user = null;
        _errorMessage = 'Access denied. Admin privileges required.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // LOG SUCCESSFUL LOGIN
      await AdminActivityLogger.logLogin(
        adminId: _user!.uid,
        adminEmail: _adminData?['email'] ?? email,
        adminName: _adminData?['name'] ?? _user!.displayName ?? 'Unknown',
        adminRole: _adminData?['role'] ?? 'viewer',
        isSuccessful: true,
      );


      // Sync verification status
      await syncVerificationStatus();

      // Check if email is verified (either Firebase Auth or Firestore)
      if (_user != null && !isEmailVerified) {
        // Only send verification email if neither Firebase Auth nor Firestore shows verified
        if (!_user!.emailVerified && !_isFirestoreVerified) {
          try {
            await _user!.sendEmailVerification();
            print('Verification email sent to ${_user!.email}');
          } catch (e) {
            print('Error sending verification email: $e');
          }
        }
      }

      // Return true even if email not verified - let UI handle verification check
      _isLoading = false;
      notifyListeners();
      return true;

    } on FirebaseAuthException catch (e) {
      _isLoading = false;

      switch (e.code) {
        case 'user-not-found':
          _errorMessage = 'No admin account found for that email.';
          break;
        case 'wrong-password':
          _errorMessage = 'Wrong password provided.';
          break;
        case 'invalid-email':
          _errorMessage = 'Invalid email address.';
          break;
        case 'user-disabled':
          _errorMessage = 'This admin account has been disabled.';
          break;
        case 'too-many-requests':
          _errorMessage = 'Too many failed login attempts. Please try again later.';
          break;
        default:
          _errorMessage = 'Login failed. Please try again.';
      }

      await AdminActivityLogger.logLogin(
        adminId: 'unknown',
        adminEmail: email,
        adminName: 'Unknown',
        adminRole: 'unknown',
        isSuccessful: false,
        errorMessage: _errorMessage,
      );

      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';

    // LOG FAILED LOGIN - Unexpected error
    await AdminActivityLogger.logLogin(
    adminId: 'unknown',
    adminEmail: email,
    adminName: 'Unknown',
    adminRole: 'unknown',
    isSuccessful: false,
    errorMessage: _errorMessage,
    );

      notifyListeners();
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      // LOG LOGOUT before clearing session
      if (_user != null && _isAdmin && _adminData != null) {
        await AdminActivityLogger.log(
          adminId: _user!.uid,
          adminEmail: _adminData?['email'] ?? _user!.email ?? '',
          adminName: _adminData?['name'] ?? _user!.displayName ?? '',
          adminRole: _adminData?['role'] ?? 'viewer',
          action: 'logout',
          actionType: 'auth',
          targetType: 'session',
        );

        // Update last logout timestamp
        await _firestore
            .collection('admins')
            .doc(_user!.uid)
            .update({
          'lastLogout': FieldValue.serverTimestamp(),
        });
      }

      await _auth.signOut();

      // Clear admin session
      AdminSessionService.instance.clearSession();

      _user = null;
      _isAdmin = false;
      _adminData = null;
      _isFirestoreVerified = false;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to sign out. Please try again.';
      notifyListeners();
    }
  }

  // Update admin profile
  Future<bool> updateProfile({
    String? displayName,
    String? photoURL,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      if (_user == null || !_isAdmin) return false;

      // Store old values for logging
      final oldName = _adminData?['name'] ?? _user!.displayName;
      final changes = <String, dynamic>{};

      // Update Firebase Auth profile
      if (displayName != null && displayName != oldName) {
        await _user!.updateDisplayName(displayName);
        changes['name'] = {'old': oldName, 'new': displayName};
      }

      if (photoURL != null) {
        await _user!.updatePhotoURL(photoURL);
        changes['photoURL'] = {'old': _adminData?['photoURL'], 'new': photoURL};
      }

      // Update Firestore admin document
      final updateData = <String, dynamic>{};

      if (displayName != null) {
        updateData['name'] = displayName;
      }

      if (photoURL != null) {
        updateData['photoURL'] = photoURL;
      }

      if (additionalData != null) {
        updateData.addAll(additionalData);
        changes['additionalData'] = additionalData;
      }

      if (updateData.isNotEmpty) {
        updateData['updatedAt'] = FieldValue.serverTimestamp();

        await _firestore
            .collection('admins')
            .doc(_user!.uid)
            .update(updateData);

        // LOG PROFILE UPDATE
        await AdminActivityLogger.log(
          adminId: _user!.uid,
          adminEmail: _adminData?['email'] ?? _user!.email ?? '',
          adminName: _adminData?['name'] ?? _user!.displayName ?? '',
          adminRole: _adminData?['role'] ?? 'viewer',
          action: 'update_profile',
          actionType: 'settings',
          targetType: 'admin_profile',
          targetId: _user!.uid,
          details: changes,
        );
      }

      await _user!.reload();
      _user = _auth.currentUser;
      await _checkAdminStatus();

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update profile: ${e.toString()}';

      // LOG FAILED PROFILE UPDATE
      await AdminActivityLogger.log(
        adminId: _user?.uid ?? 'unknown',
        adminEmail: _adminData?['email'] ?? _user?.email ?? '',
        adminName: _adminData?['name'] ?? _user?.displayName ?? '',
        adminRole: _adminData?['role'] ?? 'viewer',
        action: 'update_profile',
        actionType: 'settings',
        targetType: 'admin_profile',
        targetId: _user?.uid,
        isSuccessful: false,
        errorMessage: e.toString(),
      );

      notifyListeners();
      return false;
    }
  }


  // MODIFIED changePassword method with logging
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      if (_user == null || _user!.email == null) return false;

      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Re-authenticate the user
      final credential = EmailAuthProvider.credential(
        email: _user!.email!,
        password: currentPassword,
      );

      await _user!.reauthenticateWithCredential(credential);

      // Update password
      await _user!.updatePassword(newPassword);

      // Update password changed timestamp in Firestore
      await _firestore
          .collection('admins')
          .doc(_user!.uid)
          .update({
        'passwordChangedAt': FieldValue.serverTimestamp(),
      });

      // LOG PASSWORD CHANGE
      await AdminActivityLogger.log(
        adminId: _user!.uid,
        adminEmail: _adminData?['email'] ?? _user!.email ?? '',
        adminName: _adminData?['name'] ?? _user!.displayName ?? '',
        adminRole: _adminData?['role'] ?? 'viewer',
        action: 'password_changed',
        actionType: 'auth',
        targetType: 'account_security',
        targetId: _user!.uid,
      );

      _isLoading = false;
      notifyListeners();
      return true;

    } on FirebaseAuthException catch (e) {
      _isLoading = false;

      switch (e.code) {
        case 'wrong-password':
          _errorMessage = 'Current password is incorrect.';
          break;
        case 'weak-password':
          _errorMessage = 'The new password is too weak.';
          break;
        case 'requires-recent-login':
          _errorMessage = 'Please sign in again before changing your password.';
          break;
        default:
          _errorMessage = 'Failed to change password. Please try again.';
      }

      // LOG FAILED PASSWORD CHANGE
      await AdminActivityLogger.log(
        adminId: _user!.uid,
        adminEmail: _adminData?['email'] ?? _user!.email ?? '',
        adminName: _adminData?['name'] ?? _user!.displayName ?? '',
        adminRole: _adminData?['role'] ?? 'viewer',
        action: 'password_change_failed',
        actionType: 'auth',
        targetType: 'account_security',
        targetId: _user!.uid,
        isSuccessful: false,
        errorMessage: _errorMessage,
      );

      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred.';
      notifyListeners();
      return false;
    }
  }


  // MODIFIED resetPassword method with logging
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // First check if the email belongs to an admin
      final querySnapshot = await _firestore
          .collection('admins')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _isLoading = false;
        _errorMessage = 'No admin account found for that email.';
        notifyListeners();
        return false;
      }

      final adminDoc = querySnapshot.docs.first;
      final adminData = adminDoc.data();

      await _auth.sendPasswordResetEmail(email: email);

      // LOG PASSWORD RESET REQUEST
      await AdminActivityLogger.log(
        adminId: adminDoc.id,
        adminEmail: email,
        adminName: adminData['name'] ?? 'Unknown',
        adminRole: adminData['role'] ?? 'viewer',
        action: 'password_reset_requested',
        actionType: 'auth',
        targetType: 'account_security',
        targetId: adminDoc.id,
      );

      _isLoading = false;
      notifyListeners();
      return true;

    } on FirebaseAuthException catch (e) {
      _isLoading = false;

      switch (e.code) {
        case 'invalid-email':
          _errorMessage = 'Invalid email address.';
          break;
        case 'user-not-found':
          _errorMessage = 'No admin account found for that email.';
          break;
        default:
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


  // Get admin permissions
  List<String> get permissions {
    if (_adminData != null && _adminData!['permissions'] != null) {
      return List<String>.from(_adminData!['permissions']);
    }
    return [];
  }

  // Check if admin has specific permission
  bool hasPermission(String permission) {
    return permissions.contains(permission);
  }

  // Check if admin has any of the specified permissions
  bool hasAnyPermission(List<String> requiredPermissions) {
    return requiredPermissions.any((permission) => hasPermission(permission));
  }

  // Check if admin has all of the specified permissions
  bool hasAllPermissions(List<String> requiredPermissions) {
    return requiredPermissions.every((permission) => hasPermission(permission));
  }
}