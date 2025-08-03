// admin_auth_wrapper.dart - UPDATED VERSION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login/admin_email_verification.dart';
import '../login/admin_login_view.dart';
import 'admin_auth_provider.dart';

class AdminAuthWrapper extends StatefulWidget {
  final Widget authenticatedWidget;
  final List<String>? requiredPermissions;
  final bool requireAllPermissions;

  const AdminAuthWrapper({
    Key? key,
    required this.authenticatedWidget,
    this.requiredPermissions,
    this.requireAllPermissions = false,
  }) : super(key: key);

  @override
  State<AdminAuthWrapper> createState() => _AdminAuthWrapperState();
}

class _AdminAuthWrapperState extends State<AdminAuthWrapper> {

  @override
  void initState() {
    super.initState();
    // Check and update verification status when widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndUpdateVerification();
    });
  }

  Future<void> _checkAndUpdateVerification() async {
    if (!mounted) return;

    final authProvider = Provider.of<AdminAuthProvider>(context, listen: false);
    await authProvider.syncVerificationStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AdminAuthProvider, _AdminAuthStateSnapshot>(
      selector: (_, provider) => _AdminAuthStateSnapshot(
        isLoading: provider.isLoading,
        isAuthenticated: provider.isAuthenticated,
        isAdmin: provider.isAdmin,
        adminEmail: provider.user?.email,
        permissions: provider.permissions,
        isVerified: provider.isEmailVerified, // UPDATED: Use the new getter
      ),
      builder: (context, authState, _) {
        // Debug logging
        print('=== [AdminAuthWrapper] Rebuilt at ${DateTime.now()} ===');
        print('State -> '
            'loading: ${authState.isLoading}, '
            'authenticated: ${authState.isAuthenticated}, '
            'isAdmin: ${authState.isAdmin}, '
            'emailVerified: ${authState.isVerified}, '
            'email: ${authState.adminEmail}');
        print('Permissions -> ${authState.permissions}');

        // 1. Show loading
        if (authState.isLoading) {
          print('[AuthWrapper] Currently Loading... Showing Loader UI');
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading admin panel...'),
                ],
              ),
            ),
          );
        }

        // 2. Not Authenticated or Not Admin
        if (!authState.isAuthenticated) {
          return const AdminLoginView();
        }

        if (!authState.isVerified) {
          return const EmailVerificationScreen();
        }


        if (!authState.isAdmin) {
          print('[AuthWrapper] Authenticated but Not Admin. Redirecting to AdminLoginView.');
          return const AdminLoginView();
        }

        // 3. Email Not Verified - UPDATED to use new verification logic
        if (!authState.isVerified) {
          print('[AuthWrapper] Email Not Verified. Triggering verification sync and redirecting to AdminLoginView.');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAndUpdateVerification();
          });
          return const AdminLoginView();
        }

        // 4. Permissions Check
        if (widget.requiredPermissions != null && widget.requiredPermissions!.isNotEmpty) {
          final hasRequiredPermissions = widget.requireAllPermissions
              ? authState.permissions.toSet().containsAll(widget.requiredPermissions!)
              : widget.requiredPermissions!.any((permission) =>
              authState.permissions.contains(permission));

          if (!hasRequiredPermissions) {
            print('[AuthWrapper] Missing Required Permissions. Showing No Access UI.');
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Access Denied',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You do not have the required permissions to access this area.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/admin');
                      },
                      child: const Text('Go to Dashboard'),
                    ),
                  ],
                ),
              ),
            );
          } else {
            print('[AuthWrapper] Permissions Check Passed.');
          }
        }

        // 5. Fully Authenticated, Verified, and Authorized
        print('[AuthWrapper] All Checks Passed. Rendering Authenticated Widget.');
        return widget.authenticatedWidget;
      },
    );
  }
}

class _AdminAuthStateSnapshot {
  final bool isLoading;
  final bool isAuthenticated;
  final bool isAdmin;
  final String? adminEmail;
  final List<String> permissions;
  final bool isVerified;

  const _AdminAuthStateSnapshot({
    required this.isLoading,
    required this.isAuthenticated,
    required this.isAdmin,
    required this.adminEmail,
    required this.permissions,
    required this.isVerified,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is _AdminAuthStateSnapshot &&
              runtimeType == other.runtimeType &&
              isLoading == other.isLoading &&
              isAuthenticated == other.isAuthenticated &&
              isAdmin == other.isAdmin &&
              adminEmail == other.adminEmail &&
              permissions.toString() == other.permissions.toString() &&
              isVerified == other.isVerified;

  @override
  int get hashCode =>
      isLoading.hashCode ^
      isAuthenticated.hashCode ^
      isAdmin.hashCode ^
      (adminEmail?.hashCode ?? 0) ^
      permissions.toString().hashCode ^
      isVerified.hashCode;
}