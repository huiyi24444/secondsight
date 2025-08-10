import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secondsight/web/admin/login/activity_logger_mixin.dart';
import '../services/permissions_manager.dart';

class CreateAdminDialog extends StatefulWidget {
  const CreateAdminDialog({Key? key}) : super(key: key);

  @override
  State<CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends State<CreateAdminDialog> with ActivityLoggerMixin{
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'viewer';
  bool _isEnabled = true;
  bool _isCreating = false;

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final invitationToken = _generateInvitationToken();
      final rolePermissions = PermissionHelper.getPermissionsForRole(_selectedRole);

      // Create admin document with pending status
      final adminData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'role': _selectedRole,
        'permissions': rolePermissions,
        'isAdmin': true,
        'isEnabled': _isEnabled,
        'status': 'pending_invitation', // Key status
        'invitationToken': invitationToken,
        'invitedAt': FieldValue.serverTimestamp(),
        'invitationExpiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)), // 7-day expiry
        ),
        'createdAt': FieldValue.serverTimestamp(),
        'firebaseUid': null, // Will be set when they complete setup
        'verifiedAt': null,
        'lastLogin': null,
      };

      final adminRef = await FirebaseFirestore.instance
          .collection('admins')
          .add(adminData);

      // Send invitation email
      await _sendInvitationEmail(
        adminRef.id,
        _emailController.text.trim().toLowerCase(),
        _nameController.text.trim(),
        invitationToken,
      );

      debugPrint('✅ Invitation successfully sent to ${_emailController.text.trim().toLowerCase()} (Admin ID: ${adminRef.id})');

      // Log the invitation
      await logCrud(
        operation: 'create',
        targetType: 'admin_invitation',
        targetId: adminRef.id,
        targetName: 'Admin Invitation for ${_nameController.text.trim()}',
        changes: {
          'inviteeEmail': _emailController.text.trim().toLowerCase(),
          'inviteeName': _nameController.text.trim(),
          'assignedRole': _selectedRole,
          'permissionsCount': rolePermissions.length,
          'expiresAt': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          'invitationToken': invitationToken.substring(0, 8) + '...', // Partial token for security
        },
        isSuccessful: true,
      );

      if (mounted) {
        Navigator.of(context).pop(true);

        // Show success dialog with instructions
        _showInvitationSentDialog();
      }
    } catch (e) {
      debugPrint('❌ Failed to send invitation to ${_emailController.text.trim().toLowerCase()}: $e');
      await logCrud(
        operation: 'create',
        targetType: 'admin_invitation',
        targetId: 'invitation_failed',
        targetName: 'Failed Admin Invitation for ${_nameController.text.trim()}',
        changes: {
          'inviteeEmail': _emailController.text.trim().toLowerCase(),
          'inviteeName': _nameController.text.trim(),
          'assignedRole': _selectedRole,
          'attemptedAt': DateTime.now().toIso8601String(),
        },
        isSuccessful: false,
        errorMessage: e.toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending invitation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  String _generateInvitationToken() {
    // Generate cryptographically secure token
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 31) % 1000000; // Simple random component
    return '${timestamp}_${random}_admin_invite';
  }

  void _showInvitationSentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.mark_email_read, color: Colors.green, size: 48),
        title: const Text('Invitation Sent Successfully'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('An invitation has been sent to:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _emailController.text.trim(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Next Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('• Admin will receive setup instructions via email'),
            const Text('• Invitation expires in 7 days'),
            const Text('• They will create their own password'),
            const Text('• Account will be activated after email verification'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendInvitationEmail(
      String adminId,
      String email,
      String name,
      String token,
      ) async {
    try {
      debugPrint('🚀 Starting email send process for: $email');

      final setupUrl = 'http://localhost:8080/admin-setup?token=$token&id=$adminId';

      // FIXED: Use correct format for Firebase Email Extension
      final emailData = {
        'to': email,
        'message': {
          'subject': 'Admin Account Setup - SecondSight Platform',
          'html': _buildInvitationEmailTemplate(name, setupUrl),
          'text': 'You have been invited to join SecondSight as an admin. Please complete your setup by clicking the link in this email.',
        }
        // Removed 'from', 'replyTo' - extension uses configured defaults
      };

      debugPrint('📧 Email data format: ${emailData.keys.toList()}');
      debugPrint('📧 Message keys: ${(emailData['message'] as Map).keys.toList()}');

      final docRef = await FirebaseFirestore.instance
          .collection('mail')
          .add(emailData);

      debugPrint('✅ Email queued in Firestore: ${docRef.id}');

      // Monitor delivery status with better logging
      await _monitorEmailDelivery(docRef, email);

    } catch (e) {
      debugPrint('❌ Email sending error: $e');
      rethrow;
    }
  }

  Future<void> _monitorEmailDelivery(DocumentReference docRef, String email) async {
    debugPrint('👀 Monitoring email delivery for: $email');

    for (int i = 0; i < 15; i++) { // Wait up to 30 seconds
      await Future.delayed(const Duration(seconds: 2));

      try {
        final doc = await docRef.get();
        final data = doc.data() as Map<String, dynamic>?;

        debugPrint('📊 Document data keys: ${data?.keys.toList()}');

        if (data?['delivery'] != null) {
          final delivery = data!['delivery'] as Map<String, dynamic>;
          final state = delivery['state'];

          debugPrint('📈 Delivery state: $state');

          switch (state) {
            case 'SUCCESS':
              debugPrint('✅ Email sent successfully to $email');
              return;
            case 'ERROR':
              final error = delivery['error'];
              debugPrint('❌ Email failed: $error');
              throw Exception('Email delivery failed: $error');
            case 'PROCESSING':
              debugPrint('⏳ Email processing... (attempt ${i + 1}/15)');
              break;
            default:
              debugPrint('📋 Unknown state: $state');
          }
        } else {
          debugPrint('⏳ No delivery field yet... (attempt ${i + 1}/15)');

          // Check if there are any error fields
          if (data?.containsKey('error') == true) {
            debugPrint('⚠️ Document has error field: ${data!['error']}');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error checking delivery status: $e');
      }
    }

    debugPrint('⏰ Timeout waiting for delivery status - check Firebase Console manually');
  }

// Test method to check extension configuration
  Future<void> _testEmailConfiguration() async {
    try {
      debugPrint('🧪 Testing email configuration...');

      final testEmailData = {
        'to': 'your-test-email@gmail.com', // Replace with your email
        'message': {
          'subject': 'SecondSight Email Extension Test',
          'text': 'This is a test email to verify the Firebase Email Extension is working.',
          'html': '<p>This is a <strong>test email</strong> to verify the Firebase Email Extension is working.</p>',
        }
      };

      final docRef = await FirebaseFirestore.instance
          .collection('mail')
          .add(testEmailData);

      debugPrint('📧 Test email queued: ${docRef.id}');
      await _monitorEmailDelivery(docRef, 'test-email');

    } catch (e) {
      debugPrint('❌ Email test failed: $e');
    }
  }
  String _buildInvitationEmailTemplate(String name, String setupUrl) {
    return '''
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <title>Admin Account Setup</title>
    <style>
      body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
      .container { max-width: 600px; margin: 0 auto; padding: 20px; }
      .header { background: #7C3AED; color: white; padding: 20px; text-align: center; }
      .content { padding: 20px; background: #f9f9f9; }
      .button { 
        display: inline-block; 
        background: #7C3AED; 
        color: white; 
        padding: 12px 24px; 
        text-decoration: none; 
        border-radius: 5px; 
        margin: 20px 0;
      }
      .warning { background: #fff3cd; border: 1px solid #ffeaa7; padding: 10px; border-radius: 5px; }
    </style>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <h1>Welcome to SecondSight Admin</h1>
      </div>
      
      <div class="content">
        <h2>Hello $name,</h2>
        
        <p>You've been invited to join the SecondSight admin team! To complete your account setup, please follow these steps:</p>
        
        <ol>
          <li>Click the setup button below</li>
          <li>Verify your email address</li>
          <li>Create a secure password</li>
          <li>Access your admin dashboard</li>
        </ol>
        
        <div style="text-align: center;">
          <a href="$setupUrl" class="button">Complete Account Setup</a>
        </div>
        
        <div class="warning">
          <strong>⚠️ Important:</strong>
          <ul>
            <li>This invitation expires in 7 days</li>
            <li>The setup link can only be used once</li>
            <li>Keep your login credentials secure</li>
          </ul>
        </div>
        
        <p>If you have any questions, please contact the system administrator.</p>
        
        <hr>
        <small>
          If you can't click the button above, copy and paste this link into your browser:<br>
          $setupUrl
        </small>
      </div>
    </div>
  </body>
  </html>
  ''';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Invite New Admin',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Send an invitation to create a new admin account',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Name Field
              TextFormField(
                controller: _nameController,
                enabled: !_isCreating,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                  helperText: 'Name of the person you\'re inviting',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email Field
              TextFormField(
                controller: _emailController,
                enabled: !_isCreating,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                  helperText: 'They will receive setup instructions here',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Info box about password setup
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Secure Setup Process',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'The invited admin will create their own password during setup for security.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Role Selection with permissions preview
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Assign Role',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shield),
                    ),
                    items: AdminRoles.roles.entries.map((entry) {
                      final role = entry.value;
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Row(
                          children: [
                            Text(role.name),
                            const SizedBox(width: 8),
                            Text(
                              '(${role.permissions.length} permissions)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _isCreating ? null : (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  // Show role description
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AdminRoles.roles[_selectedRole]?.description ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Active Status
              SwitchListTile(
                title: const Text('Active After Setup'),
                subtitle: const Text('Admin can access system immediately after completing setup'),
                value: _isEnabled,
                onChanged: _isCreating ? null : (value) {
                  setState(() {
                    _isEnabled = value;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isCreating ? null : _createAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                    child: _isCreating
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send, size: 16),
                        SizedBox(width: 8),
                        Text('Send Invitation'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}