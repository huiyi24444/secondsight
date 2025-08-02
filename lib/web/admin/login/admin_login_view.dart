// admin_login_view.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/admin_auth_provider.dart';

class AdminLoginView extends StatefulWidget {
  const AdminLoginView({Key? key}) : super(key: key);

  @override
  State<AdminLoginView> createState() => _AdminLoginViewState();
}

class _AdminLoginViewState extends State<AdminLoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if widget is still mounted before any setState calls
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AdminAuthProvider>(context, listen: false);

    final success = await authProvider.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    // CRITICAL FIX: Check mounted before setState
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      // Check if email is verified
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        // Email not verified - show verification dialog
        // Only show dialog if widget is still mounted
        if (mounted) {
          _showEmailVerificationDialog();
        }
        return;
      }
      // If verified, navigation will be handled by the auth provider
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Login failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEmailVerificationDialog() {
    // Additional mounted check before showing dialog
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.email_outlined, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Email Verification Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your email address needs to be verified before you can access the admin dashboard.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Check your email inbox and click the verification link.',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Sign out and close dialog
              await FirebaseAuth.instance.signOut();
              // Check if still mounted before navigation
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Resend verification email
              await _resendVerificationEmail();
            },
            child: const Text('Resend Email'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Check verification status
              await _checkEmailVerification();
            },
            child: const Text('I\'ve Verified'),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        // Check mounted before showing snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification email sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      // Check mounted before showing snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkEmailVerification() async {
    try {
      // Reload user data to get latest verification status
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        // Refresh the auth provider
        final authProvider = Provider.of<AdminAuthProvider>(context, listen: false);
        await authProvider.refreshUserStatus();

        // Check mounted before navigation and snackbar
        if (mounted) {
          Navigator.of(context).pop(); // Close verification dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email verified successfully! Redirecting...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Check mounted before showing snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email not verified yet. Please check your email and try again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // Check mounted before showing snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking verification: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 800;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isLargeScreen ? 450 : double.infinity,
                ),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo/Icon
                          Icon(
                            Icons.admin_panel_settings,
                            size: 64,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(height: 24),

                          // Title
                          Text(
                            'Admin Portal',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to access the admin dashboard',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  if (mounted) {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  }
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Login button
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                                  : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Forgot password
                          TextButton(
                            onPressed: () {
                              _showForgotPasswordDialog();
                            },
                            child: const Text('Forgot Password?'),
                          ),

                          // Error message
                          Consumer<AdminAuthProvider>(
                            builder: (context, authProvider, _) {
                              if (authProvider.errorMessage != null) {
                                return Container(
                                  margin: const EdgeInsets.only(top: 16),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red[700],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          authProvider.errorMessage!,
                                          style: TextStyle(
                                            color: Colors.red[700],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    // Check mounted before showing dialog
    if (!mounted) return;

    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                final authProvider = Provider.of<AdminAuthProvider>(
                  context,
                  listen: false,
                );

                final success = await authProvider.resetPassword(email);

                // Check context.mounted instead of mounted here since this is in a dialog
                if (context.mounted) {
                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Password reset email sent successfully'
                            : authProvider.errorMessage ?? 'Failed to send reset email',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }
}