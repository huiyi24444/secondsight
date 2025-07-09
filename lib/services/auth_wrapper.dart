
// auth_wrapper.dart - Updated to handle email verification
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
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show loading indicator while checking auth state
        if (authProvider.isLoading && authProvider.user == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is authenticated
        if (authProvider.isAuthenticated) {
          // Check if email is verified
          if (!authProvider.isEmailVerified) {
            return EmailVerificationView(
              email: authProvider.user?.email ?? '',
            );
          }
          // Email is verified, show main app
          return authenticatedWidget;
        }

        // Otherwise, show login screen
        return const LoginView();
      },
    );
  }
}
