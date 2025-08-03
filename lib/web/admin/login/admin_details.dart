// admin_details_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../admin_main.dart';
import '../../../model/admin_log_model.dart';
import '../services/admin_auth_provider.dart';
import '../services/permissions_manager.dart';
import '../widget/sidebar.dart';
import '../widget/topbar.dart';

class AdminDetailsPage extends StatefulWidget {
  final Map<String, dynamic> admin;
  final String adminId;

  const AdminDetailsPage({
    Key? key,
    required this.admin,
    required this.adminId,
  }) : super(key: key);

  @override
  State<AdminDetailsPage> createState() => _AdminDetailsPageState();
}

class _AdminDetailsPageState extends State<AdminDetailsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AdminLogModel> _activityLogs = [];
  bool _isLoadingLogs = true;
  String _selectedLogFilter = 'All';
  final ScrollController _scrollController = ScrollController();
  String currentPage = 'admins';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadActivityLogs();
  }

  Future<void> _loadActivityLogs() async {
    try {
      setState(() => _isLoadingLogs = true);

      // Load logs from subcollection
      final logsSnapshot = await FirebaseFirestore.instance
          .collection('admins')
          .doc(widget.adminId)
          .collection('activity_logs')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final logs = logsSnapshot.docs
          .map((doc) => AdminLogModel.fromDocument(doc))
          .toList();

      setState(() {
        _activityLogs = logs;
        _isLoadingLogs = false;
      });
    } catch (e) {
      print('Error loading activity logs: $e');
      setState(() => _isLoadingLogs = false);
    }
  }

  List<AdminLogModel> get filteredLogs {
    if (_selectedLogFilter == 'All') return _activityLogs;

    return _activityLogs.where((log) {
      switch (_selectedLogFilter) {
        case 'Account':
          return log.action.contains('login') ||
              log.action.contains('logout') ||
              log.action.contains('password');
        case 'Data Changes':
          return log.action.contains('create') ||
              log.action.contains('update') ||
              log.action.contains('delete');
        case 'Settings':
          return log.action.contains('settings') ||
              log.action.contains('permission');
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminAuthProvider>(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Sidebar - Fixed width on the left
          AdminSidebar(
            onPageChanged: (String page) {
              // Always go back to AdminNavigator with the selected page
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (context) => AdminNavigator(initialPage: page)
                ),
                    (route) => false,
              );
            },
            currentPage: 'admins',
            adminPermissions: adminProvider.permissions,
          ),

          // Main content area - Takes remaining space
          Expanded(
            child: Column(
              children: [
                const CustomTopBar(
                  title: 'Admin',
                  subtitle: 'Admin Details',
                ),
                // Admin Header Info
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xFF7C3AED).withOpacity(0.1),
                            child: Text(
                              widget.admin['name'][0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 36,
                                color: Color(0xFF7C3AED),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      widget.admin['name'],
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(widget.admin['role']).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatRole(widget.admin['role']),
                                        style: TextStyle(
                                          color: _getRoleColor(widget.admin['role']),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.admin['email'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Last active: ${widget.admin['lastActive']}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: widget.admin['isActive']
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: widget.admin['isActive'] ? Colors.green : Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            widget.admin['isActive'] ? 'Active' : 'Inactive',
                                            style: TextStyle(
                                              color: widget.admin['isActive'] ? Colors.green : Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tab Bar
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF7C3AED),
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: const Color(0xFF7C3AED),
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Permissions'),
                      Tab(text: 'Activity Log'),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Overview Tab
                      _buildOverviewTab(),
                      // Permissions Tab
                      _buildPermissionsTab(),
                      // Activity Log Tab
                      _buildActivityLogTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Cards Row
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Admin ID',
                  '#${widget.adminId}',
                  Icons.fingerprint,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  'Created Date',
                  '3 months ago',
                  Icons.calendar_today,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  'Total Actions',
                  '${_activityLogs.length}',
                  Icons.analytics,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Contact Information
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Email', widget.admin['email'], Icons.email),
                const Divider(height: 24),
                _buildDetailRow('Phone', widget.admin['phone'] ?? 'Not provided', Icons.phone),
                const Divider(height: 24),
                _buildDetailRow('Department', widget.admin['department'] ?? 'Not assigned', Icons.business),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Recent Activity Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Activity Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildActivitySummaryItem('Last Login', widget.admin['lastActive'], Icons.login),
                const SizedBox(height: 12),
                _buildActivitySummaryItem('Total Logins This Month', '45', Icons.timeline),
                const SizedBox(height: 12),
                _buildActivitySummaryItem('Failed Login Attempts', '2', Icons.error_outline),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsTab() {
    final rolePermissions = _getRolePermissions(widget.admin['role']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Permissions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on ${_formatRole(widget.admin['role'])} role',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Edit permissions
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Permissions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...rolePermissions.map((permission) => _buildPermissionItem(permission)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityLogTab() {
    return Column(
      children: [
        // Filter Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Filter by: ',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
              ...[
                'All',
                'Account',
                'Data Changes',
                'Settings',
              ].map((filter) {
                final isActive = _selectedLogFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isActive,
                    onSelected: (selected) {
                      setState(() {
                        _selectedLogFilter = filter;
                      });
                    },
                    selectedColor: const Color(0xFF7C3AED).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF7C3AED),
                    labelStyle: TextStyle(
                      color: isActive ? const Color(0xFF7C3AED) : Colors.grey[700],
                    ),
                  ),
                );
              }).toList(),
              const Spacer(),
              TextButton.icon(
                onPressed: _loadActivityLogs,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),

        // Activity Log List
        Expanded(
          child: _isLoadingLogs
              ? const Center(child: CircularProgressIndicator())
              : filteredLogs.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No activity logs found',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          )
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: filteredLogs.length,
            itemBuilder: (context, index) {
              final log = filteredLogs[index];
              return _buildLogItem(log);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(AdminLogModel log) {
    final icon = _getLogIcon(log.action);
    final color = _getLogColor(log.action);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.action,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (log.details != null && log.details!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatLogDetails(log.details!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('MMM d, y').format(log.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                DateFormat('h:mm a').format(log.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySummaryItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionItem(String permission) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              permission,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLogIcon(String action) {
    if (action.contains('login')) return Icons.login;
    if (action.contains('logout')) return Icons.logout;
    if (action.contains('create')) return Icons.add_circle;
    if (action.contains('update')) return Icons.edit;
    if (action.contains('delete')) return Icons.delete;
    if (action.contains('view')) return Icons.visibility;
    if (action.contains('settings')) return Icons.settings;
    if (action.contains('permission')) return Icons.security;
    return Icons.circle;
  }

  Color _getLogColor(String action) {
    if (action.contains('login') || action.contains('logout')) return Colors.blue;
    if (action.contains('create')) return Colors.green;
    if (action.contains('update')) return Colors.orange;
    if (action.contains('delete')) return Colors.red;
    if (action.contains('settings') || action.contains('permission')) return Colors.purple;
    return Colors.grey;
  }

  String _formatLogDetails(Map<String, dynamic> details) {
    final List<String> parts = [];
    details.forEach((key, value) {
      if (value != null) {
        parts.add('$key: $value');
      }
    });
    return parts.join(', ');
  }

  String _formatRole(String role) {
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

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin':
        return Colors.purple;
      case 'admin':
        return Colors.blue;
      case 'manager':
        return Colors.orange;
      case 'support':
        return Colors.green;
      case 'viewer':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  List<String> _getRolePermissions(String role) {
    // This should come from your actual permissions system
    switch (role) {
      case 'super_admin':
        return [
          'Full system access',
          'Manage all admins',
          'View all data',
          'Modify system settings',
          'Access audit logs',
        ];
      case 'admin':
        return [
          'Manage users',
          'View reports',
          'Modify content',
          'Access analytics',
        ];
      case 'manager':
        return [
          'View reports',
          'Manage team',
          'Approve requests',
        ];
      case 'support':
        return [
          'View user data',
          'Handle support tickets',
          'Basic modifications',
        ];
      case 'viewer':
        return [
          'View data only',
          'Generate reports',
        ];
      default:
        return [];
    }
  }

  void _showEditDialog() {
    // Implement edit dialog
  }

  void _showResetPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Send password reset email to ${widget.admin['email']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password reset email sent')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  void _toggleAdminStatus() {
    setState(() {
      widget.admin['isActive'] = !widget.admin['isActive'];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.admin['isActive']
              ? 'Admin activated successfully'
              : 'Admin deactivated successfully',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}