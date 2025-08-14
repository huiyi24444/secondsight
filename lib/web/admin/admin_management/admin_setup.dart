import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../login/activity_logger_mixin.dart';

class AdminSetupPage extends StatefulWidget {
  final String token;
  final String adminId;

  const AdminSetupPage({
    Key? key,
    required this.token,
    required this.adminId,
  }) : super(key: key);

  @override
  State<AdminSetupPage> createState() => _AdminSetupPageState();
}

class _AdminSetupPageState extends State<AdminSetupPage> with ActivityLoggerMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = true;
  bool _isSettingUp = false;
  bool _isValidToken = false;
  Map<String, dynamic>? _adminData;

  @override
  void initState() {
    super.initState();
    _validateToken();
  }

  Future<void> _validateToken() async {
    try {
      // Check if token is valid and not expired
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(widget.adminId)
          .get();

      if (!adminDoc.exists) {
        throw Exception('Admin record not found');
      }

      final data = adminDoc.data()!;
      final token = data['invitationToken'] as String?;
      final expiresAt = (data['invitationExpiresAt'] as Timestamp?)?.toDate();
      final status = data['status'] as String?;

      if (token != widget.token) {
        throw Exception('Invalid token');
      }

      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        throw Exception('Invitation has expired');
      }

      if (status != 'pending_invitation') {
        throw Exception('Invitation already used or invalid');
      }

      setState(() {
        _isValidToken = true;
        _adminData = data;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _isValidToken = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid or expired invitation: $e')),
      );
    }
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSettingUp = true;
    });

    try {
      // Create Firebase Auth account
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _adminData!['email'],
        password: _passwordController.text,
      );

      // Update admin document
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(widget.adminId)
          .update({
        'firebaseUid': credential.user!.uid,
        'status': 'active',
        'verifiedAt': FieldValue.serverTimestamp(),
        'invitationToken': null, // Remove token
        'invitationExpiresAt': null,
        'setupCompletedAt': FieldValue.serverTimestamp(),
      });

      // Send verification email
      await credential.user!.sendEmailVerification();

      // Log successful setup
      await logCrud(
        operation: 'update',
        targetType: 'admin_setup',
        targetId: widget.adminId,
        targetName: 'Admin Setup Completed for ${_adminData!['name']}',
        changes: {
          'email': _adminData!['email'],
          'role': _adminData!['role'],
          'setupCompletedAt': DateTime.now().toIso8601String(),
          'firebaseUidCreated': true,
        },
        isSuccessful: true,
      );

      // Show success and redirect
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            title: const Text('Setup Complete!'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Your admin account has been created successfully.'),
                SizedBox(height: 16),
                Text('Next steps:'),
                Text('• Check your email for verification link'),
                Text('• Verify your email address'),
                Text('• Sign in to your admin dashboard'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/admin-login');
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      await logCrud(
        operation: 'update',
        targetType: 'admin_setup',
        targetId: widget.adminId,
        targetName: 'Failed Admin Setup for ${_adminData?['name'] ?? 'Unknown'}',
        changes: {
          'email': _adminData?['email'],
          'attemptedAt': DateTime.now().toIso8601String(),
        },
        isSuccessful: false,
        errorMessage: e.toString(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Setup failed: $e')),
      );
    } finally {
      setState(() {
        _isSettingUp = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isValidToken) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Invalid or Expired Invitation',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Please contact your administrator for a new invitation.'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/admin-login'),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete Admin Setup',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome, ${_adminData!['name']}!',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),

                // Email (read-only)
                TextFormField(
                  initialValue: _adminData!['email'],
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),

                // Role (read-only)
                TextFormField(
                  initialValue: _adminData!['role'].toString().toUpperCase(),
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.shield),
                  ),
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !_isSettingUp,
                  decoration: const InputDecoration(
                    labelText: 'Create Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    helperText: 'Minimum 8 characters',
                  ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
                        return 'Password must contain at least one uppercase letter';
                      }
                      if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
                        return 'Password must contain at least one lowercase letter';
                      }
                      if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
                        return 'Password must contain at least one number';
                      }
                      if (!RegExp(r'(?=.*[!@#\$&*~])').hasMatch(value)) {
                        return 'Password must contain at least one special character';
                      }
                      return null;
                    }

                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  enabled: !_isSettingUp,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Setup Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSettingUp ? null : _completeSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSettingUp
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Complete Setup', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}