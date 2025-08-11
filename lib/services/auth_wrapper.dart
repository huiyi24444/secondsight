import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view/login/login_view.dart';
import '../view/login/verification_view.dart';
import 'auth_provider.dart';

class AuthWrapper extends StatelessWidget {
  final Widget authenticatedWidget;
  final bool requireAuth;

  const AuthWrapper({
    Key? key,
    required this.authenticatedWidget,
    this.requireAuth = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<AuthProvider, _AuthStateSnapshot>(
      selector: (_, provider) => _AuthStateSnapshot(
        isLoading: provider.isLoading,
        isAuthenticated: provider.isAuthenticated,
        isEmailVerified: provider.isEmailVerified,
        userEmail: provider.user?.email,
      ),
      builder: (context, authState, _) {
        print('[AuthWrapper] Rebuilt at ${DateTime.now()}');
        print('[AuthWrapper] State: '
            'loading=${authState.isLoading}, '
            'authenticated=${authState.isAuthenticated}, '
            'verified=${authState.isEmailVerified}, '
            'email=${authState.userEmail}'
            'requireAuth=$requireAuth');

        // 1. Show loading only if we're checking authentication
        if (authState.isLoading && requireAuth) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If authentication is required and user is authenticated but unverified
        if (requireAuth && authState.isAuthenticated && !authState.isEmailVerified) {
          return EmailVerificationView(
            email: authState.userEmail ?? '',
          );
        }

        // 3. If authentication is required but user is not authenticated
        if (requireAuth && !authState.isAuthenticated) {
          return const LoginView();
        }

        // 4. All other cases: show the authenticated widget
        // This includes:
        // - Authenticated & verified users
        // - Non-authenticated users (when requireAuth = false)
        // - During loading (when requireAuth = false)
        return authenticatedWidget;
      },
    );
  }
}

class _AuthStateSnapshot {
  final bool isLoading;
  final bool isAuthenticated;
  final bool isEmailVerified;
  final String? userEmail;

  const _AuthStateSnapshot({
    required this.isLoading,
    required this.isAuthenticated,
    required this.isEmailVerified,
    required this.userEmail,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is _AuthStateSnapshot &&
              runtimeType == other.runtimeType &&
              isLoading == other.isLoading &&
              isAuthenticated == other.isAuthenticated &&
              isEmailVerified == other.isEmailVerified &&
              userEmail == other.userEmail;

  @override
  int get hashCode =>
      isLoading.hashCode ^
      isAuthenticated.hashCode ^
      isEmailVerified.hashCode ^
      (userEmail?.hashCode ?? 0);
}
