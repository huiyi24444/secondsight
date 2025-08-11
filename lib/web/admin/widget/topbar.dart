import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_auth_provider.dart';
class CustomTopBar extends StatefulWidget {
  final String title;
  final String? subtitle;

  const CustomTopBar({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  State<CustomTopBar> createState() => _CustomTopBarState();
}

class _CustomTopBarState extends State<CustomTopBar> {
  bool isHovered = false;
  String adminName = ' ';

  @override
  void initState() {
    super.initState();
    _loadAdminName();
  }

  Future<void> _loadAdminName() async {
    try {
      final adminProvider = Provider.of<AdminAuthProvider>(context, listen: false);
      final userId = adminProvider.userId; // Assuming AdminAuthProvider has userId property

      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(userId)
            .get();

        if (userDoc.exists && mounted) {
          final userData = userDoc.data();
          setState(() {
            adminName = userData?['name'] ?? 'Admin';
          });
        }
      }
    } catch (e) {
      print('Error fetching admin name: $e');
      // Keep default 'Admin' name if error occurs
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminAuthProvider>(context);
    return Container(
      height: 60,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (widget.subtitle == null)
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Row(
              children: [
                MouseRegion(
                  onEnter: (_) => setState(() => isHovered = true),
                  onExit: (_) => setState(() => isHovered = false),
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(4),
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        decoration:
                        isHovered ? TextDecoration.underline : TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right, color: Colors.grey),
                const SizedBox(width: 10),
                Text(
                  widget.subtitle!,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

          const Spacer(),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF7C3AED).withOpacity(0.1),
            child: Text(
              adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
              style: const TextStyle(
                fontSize: 20,
                color: Color(0xFF7C3AED),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Add confirmation dialog
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  print('🚪 Starting logout process...');
                  await adminProvider.signOut();
                  print('✅ Logout successful');

                  if (mounted) {
                    // FIXED: Use the correct route
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/admin/login', // Changed from '/admin' to '/admin/login'
                          (route) => false, // Clear all routes
                    );
                  }
                } catch (e) {
                  print('❌ Logout error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Logout failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}

