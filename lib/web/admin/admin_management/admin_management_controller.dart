import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../model/admin_model.dart';
import '../login/activity_logger_mixin.dart';
import '../services/permissions_manager.dart';

class AdminController with ActivityLoggerMixin{
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  Future<List<Map<String, dynamic>>> getAdmins() async {
    final querySnapshot = await FirebaseFirestore.instance.collection('admins').get();

    return querySnapshot.docs.map((doc) {
      final admin = AdminModel.fromDocument(doc);

      final lastActive = formatTimeAgo(admin.lastLogin); // move this helper function to a util file

      return {
        'id': admin.id,
        'name': admin.name,
        'email': admin.email,
        'role': admin.role,
        'isActive': admin.isEnabled,
        'lastActive': lastActive,
        'createdAt': admin.createdAt,
      };
    }).toList();
  }

  // NEW: Toggle admin status (activate/deactivate)
  Future<bool> toggleAdminStatus(String adminId, bool currentStatus, BuildContext context) async {
    try {
      final newStatus = !currentStatus;

      // First, get the admin document to check if it exists
      final adminDoc = await _firestore.collection('admins').doc(adminId).get();

      if (!adminDoc.exists) {
        // Try to find by firebaseUid or email (similar to auth provider logic)
        final querySnapshot = await _firestore
            .collection('admins')
            .where('firebaseUid', isEqualTo: adminId)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          throw Exception('Admin not found');
        }

        // Update using the found document
        await querySnapshot.docs.first.reference.update({
          'isEnabled': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
          'statusChangedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update using the document ID
        await adminDoc.reference.update({
          'isEnabled': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
          'statusChangedAt': FieldValue.serverTimestamp(),
        });
      }

      // Get admin data for logging
      final adminData = adminDoc.exists
          ? adminDoc.data() as Map<String, dynamic>
          : (await _firestore.collection('admins').where('firebaseUid', isEqualTo: adminId).get()).docs.first.data();

      // Log the status change
      await logCrud(
        operation: 'update',
        targetType: 'admin_status',
        targetId: adminId,
        targetName: 'Admin Status Change for ${adminData['name'] ?? 'Unknown'}',
        changes: {
          'previousStatus': currentStatus ? 'active' : 'inactive',
          'newStatus': newStatus ? 'active' : 'inactive',
          'isEnabled': newStatus,
          'changedAt': DateTime.now().toIso8601String(),
          'adminEmail': adminData['email'],
          'adminRole': adminData['role'],
        },
        isSuccessful: true,
      );

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                newStatus
                    ? 'Admin activated successfully'
                    : 'Admin deactivated successfully'
            ),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
          ),
        );
      }

      return true;
    } catch (e) {
      print('❌ Error toggling admin status: $e');

      // Log the failed attempt
      await logCrud(
        operation: 'update',
        targetType: 'admin_status',
        targetId: adminId,
        targetName: 'Failed Admin Status Change',
        changes: {
          'attemptedStatus': !currentStatus ? 'active' : 'inactive',
          'attemptedAt': DateTime.now().toIso8601String(),
        },
        isSuccessful: false,
        errorMessage: e.toString(),
      );

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${!currentStatus ? 'activate' : 'deactivate'} admin: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return false;
    }
  }


  // NEW: Update admin details
  Future<bool> updateAdmin({
    required String adminId,
    required String name,
    required String email,
    required String role,
    String? phone,
    String? department,
    required bool isActive,
    required BuildContext context,
  }) async {
    try {
      // Get current admin data for comparison
      final adminDoc = await _firestore.collection('admins').doc(adminId).get();

      if (!adminDoc.exists) {
        throw Exception('Admin not found');
      }

      final currentData = adminDoc.data() as Map<String, dynamic>;
      final currentName = currentData['name'] ?? '';
      final currentEmail = currentData['email'] ?? '';
      final currentRole = currentData['role'] ?? '';
      final currentPhone = currentData['phone'];
      final currentDepartment = currentData['department'];
      final currentStatus = currentData['isEnabled'] ?? false;

      // Check what actually changed
      final Map<String, dynamic> changes = {};
      final Map<String, dynamic> previousData = {};

      if (currentName != name) {
        changes['name'] = name;
        previousData['name'] = currentName;
      }
      if (currentEmail != email) {
        changes['email'] = email;
        previousData['email'] = currentEmail;
      }
      if (currentRole != role) {
        changes['role'] = role;
        previousData['role'] = currentRole;
      }
      if (currentStatus != isActive) {
        changes['isEnabled'] = isActive;
        changes['status'] = isActive ? 'active' : 'inactive';
        previousData['isEnabled'] = currentStatus;
        previousData['status'] = currentStatus ? 'active' : 'inactive';
      }

      // If no changes, don't update
      if (changes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No changes detected')),
          );
        }
        return true;
      }

      // Update the admin document
      await adminDoc.reference.update({
        'name': name,
        'email': email,
        'role': role,
        'phone': phone,
        'department': department,
        'isEnabled': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      changes['updatedAt'] = DateTime.now().toIso8601String();

      // Log the successful update
      await logCrud(
        operation: 'update',
        targetType: 'admin',
        targetId: adminId,
        targetName: 'Admin Profile Update for $name',
        changes: changes,
        previousData: previousData,
        isSuccessful: true,
      );

      if (previousData.containsKey('role')) {
        await logCrud(
          operation: 'update',
          targetType: 'admin_permission',
          targetId: adminId,
          targetName: 'Role Change for $name',
          changes: {
            'newRole': role,
            'permissionsChanged': true,
            'permissionAction': 'role_changed',
          },
          previousData: {
            'role': previousData['role'],
          },
          isSuccessful: true,
        );
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      return true;
    } catch (e) {
      print('❌ Error updating admin: $e');

      // Log the failed attempt
      await logCrud(
        operation: 'update',
        targetType: 'admin',
        targetId: adminId,
        targetName: 'Failed Admin Profile Update for $name',
        changes: {
          'attemptedName': name,
          'attemptedEmail': email,
          'attemptedRole': role,
          'attemptedStatus': isActive,
          'attemptedAt': DateTime.now().toIso8601String(),
        },
        isSuccessful: false,
        errorMessage: e.toString(),
      );

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update admin: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return false;
    }
  }

  // NEW: Dedicated deactivate function
  Future<bool> deactivateAdmin(String adminId, BuildContext context) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Deactivate Admin'),
          content: const Text(
            'Are you sure you want to deactivate this admin? '
                'They will no longer be able to access the system.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text(
                'Deactivate',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return false;

      // Proceed with deactivation
      return await toggleAdminStatus(adminId, true, context);
    } catch (e) {
      print('❌ Error in deactivateAdmin: $e');
      return false;
    }
  }

  // NEW: Dedicated activate function
  Future<bool> activateAdmin(String adminId, BuildContext context) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Activate Admin'),
          content: const Text(
            'Are you sure you want to activate this admin? '
                'They will be able to access the system again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text(
                'Activate',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return false;

      // Proceed with activation
      return await toggleAdminStatus(adminId, false, context);
    } catch (e) {
      print('❌ Error in activateAdmin: $e');
      return false;
    }
  }

  String formatTimeAgo(DateTime? time) {
    if (time == null) return 'N/A';

    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${time.day}/${time.month}/${time.year}';
  }

  String formatRole(String role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'support':
        return 'Support';
      case 'viewer':
        return 'Viewer';
      default:
        return role;
    }
  }



}


class EditAdminDialog extends StatefulWidget {
  final Map<String, dynamic> admin;
  final AdminController controller;

  const EditAdminDialog({
    Key? key,
    required this.admin,
    required this.controller,
  }) : super(key: key);

  @override
  State<EditAdminDialog> createState() => _EditAdminDialogState();
}

class _EditAdminDialogState extends State<EditAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late String _selectedRole;
  late String? _selectedDepartment;
  late bool _isActive;
  bool _isLoading = false;

  // List of available departments
  final List<String> _departments = [
    'Human Resources',
    'Information Technology',
    'Finance',
    'Marketing',
    'Operations',
    'Customer Service',
    'Legal',
    'Sales',
    'Administration',
    'Security',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.admin['name']);
    _phoneController = TextEditingController(text: widget.admin['phone'] ?? '');
    _selectedRole = widget.admin['role'];
    _selectedDepartment = widget.admin['department'];
    _isActive = widget.admin['isActive'];
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
                    'Edit Admin',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Name Field
              TextFormField(
                controller: _nameController,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email Field (Read-only)
              TextFormField(
                initialValue: widget.admin['email'],
                enabled: false, // Make email read-only
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                  fillColor: Colors.grey[100],
                  filled: true,
                  suffixIcon: Tooltip(
                    message: 'Email cannot be modified',
                    child: Icon(Icons.lock, color: Colors.grey[600]),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Phone Field
              TextFormField(
                controller: _phoneController,
                enabled: !_isLoading,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  hintText: '60123456789',
                  helperText: 'Format: 60XXXXXXXXX (11 digits starting with 60)',
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    // Remove any spaces or special characters
                    final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');

                    // Check if it's exactly 11 digits and starts with 60
                    if (cleanValue.length != 11) {
                      return 'Phone number must be exactly 11 digits';
                    }
                    if (!cleanValue.startsWith('60')) {
                      return 'Phone number must start with 60';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(cleanValue)) {
                      return 'Phone number must contain only digits';
                    }
                  }
                  return null;
                },
                onChanged: (value) {
                  // Auto-format the input to remove non-digits
                  final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (cleanValue != value) {
                    _phoneController.value = TextEditingValue(
                      text: cleanValue,
                      selection: TextSelection.collapsed(offset: cleanValue.length),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),

              // Department Selection
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                onChanged: _isLoading ? null : (value) {
                  setState(() {
                    _selectedDepartment = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                hint: const Text('Select Department'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Not Assigned'),
                  ),
                  ..._departments.map((department) {
                    return DropdownMenuItem<String>(
                      value: department,
                      child: Text(department),
                    );
                  }).toList(),
                ],
              ),
              const SizedBox(height: 16),

              // Role Selection
              DropdownButtonFormField<String>(
                value: _selectedRole,
                onChanged: _isLoading ? null : (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.admin_panel_settings),
                ),
                items: AdminRoles.roles.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value.name),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Active Status
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SwitchListTile(
                  title: const Text('Active Status'),
                  subtitle: const Text('Admin can access the system'),
                  value: _isActive,
                  onChanged: _isLoading ? null : (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                  secondary: Icon(
                    _isActive ? Icons.check_circle : Icons.cancel,
                    color: _isActive ? Colors.green : Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Save Changes',
                      style: TextStyle(color: Colors.white),
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await widget.controller.updateAdmin(
        adminId: widget.admin['id'],
        name: _nameController.text.trim(),
        email: widget.admin['email'], // Keep original email
        role: _selectedRole,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        department: _selectedDepartment,
        isActive: _isActive,
        context: context,
      );

      if (success && mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}