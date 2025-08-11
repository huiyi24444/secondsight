import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../admin_management/admin_details.dart';
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
  String adminName = ' ';
  bool isHovered = false;
  bool isAvatarHovered = false;

  @override
  void initState() {
    super.initState();
  }

  void _navigateToAdminDetails(AdminAuthProvider adminProvider) {
    if (adminProvider.userId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminDetailsPage(
            adminId: adminProvider.userId!,
            initialAdminData: adminProvider.adminData,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load admin details'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminAuthProvider>(context);
    final displayName = adminProvider.adminName ?? 'Admin';
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

          // Clickable Avatar with Hover Effect
          Tooltip(
            message: 'View Profile',
            child: MouseRegion(
              onEnter: (_) => setState(() => isAvatarHovered = true),
              onExit: (_) => setState(() => isAvatarHovered = false),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _navigateToAdminDetails(adminProvider),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: isAvatarHovered
                          ? [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF7C3AED).withOpacity(0.1),
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'A',
                        style: TextStyle(
                          fontSize: 20,
                          color: isAvatarHovered
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF7C3AED),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 50),
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

