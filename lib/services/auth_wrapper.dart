import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view/login/login_view.dart';
import '../view/login/verification_view.dart';
import 'auth_provider.dart';

class AuthWrapper extends StatelessWidget {
  final Widget authenticatedWidget;

  const AuthWrapper({
    Key? key,
    required this.authenticatedWidget,
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
            'email=${authState.userEmail}');

        // 1. Show loading
        if (authState.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Unverified but authenticated
        if (authState.isAuthenticated && !authState.isEmailVerified) {
          return EmailVerificationView(
            email: authState.userEmail ?? '',
          );
        }

        // 3. Verified & authenticated
        if (authState.isAuthenticated) {
          return authenticatedWidget;
        }

        // 4. Not authenticated
        return const LoginView();
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
