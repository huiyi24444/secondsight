// admin_details_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:secondsight/view/widgets/dateTime_utils.dart';
import '../../../admin_main.dart';
import '../../../model/admin_log_model.dart';
import '../../../model/admin_model.dart';
import '../../../view/widgets/user_utils.dart';
import '../services/admin_auth_provider.dart';
import '../services/admin_nav.dart';
import '../services/permissions_manager.dart';
import '../widget/sidebar.dart';
import '../widget/topbar.dart';
import 'admin_details_controller.dart';

class AdminDetailsPage extends StatefulWidget {
  final String adminId;
  final Map<String, dynamic>? initialAdminData; // Made optional since we'll fetch from controller

  const AdminDetailsPage({
    Key? key,
    required this.adminId,
    this.initialAdminData,
  }) : super(key: key);

  @override
  State<AdminDetailsPage> createState() => _AdminDetailsPageState();
}

class _AdminDetailsPageState extends State<AdminDetailsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  String currentPage = 'admins';
  late AdminDetailsController _controller;

  AdminActivityLog? _selectedLog;
  bool _showDetailsPanel = false;
  double _detailsPanelWidth = 400.0;
  final double _minPanelWidth = 300.0;
  final double _maxPanelWidth = 600.0;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _controller = AdminDetailsController();
    _loadData();
    _controller.loadActivityLogs(widget.adminId);
  }

  Future<void> _loadData() async {
    await _controller.fetchAdminById(widget.adminId);
  }



  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminAuthProvider>(context);

    return ChangeNotifierProvider<AdminDetailsController>.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: Consumer<AdminDetailsController>(
          builder: (context, controller, child) {
            // Handle loading state
            if (controller.isLoading) {
              return Row(
                children: [
                  AdminSidebar(
                    onPageChanged: (String page) {
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
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ],
              );
            }

            // Handle error state
            if (controller.error != null) {
              return Row(
                children: [
                  AdminSidebar(
                    onPageChanged: (String page) {
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
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            controller.error!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadData(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            // Handle case where admin data is not available
            if (!controller.hasData) {
              return Row(
                children: [
                  AdminSidebar(
                    onPageChanged: (String page) {
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
                  const Expanded(
                    child: Center(
                      child: Text('Admin not found'),
                    ),
                  ),
                ],
              );
            }

            // Main content when data is available
            final admin = controller.admin!;
            return Row(
              children: [
                // Sidebar - Fixed width on the left
                AdminSidebar(
                  onPageChanged: (String page) {
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
                                    admin.name[0].toUpperCase(),
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
                                            admin.name,
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _controller.getRoleColor(admin.role).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _controller.formatRole(admin.role),
                                              style: TextStyle(
                                                color: _controller.getRoleColor(admin.role),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (admin.isVerified) ...[
                                            const SizedBox(width: 8),
                                            Tooltip(
                                              message: 'Verified Admin',
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.verified,
                                                  size: 16,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        admin.email,
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
                                            'Last active: ${_controller.formatDateTime(admin.lastLogout)}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: admin.isEnabled
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
                                                    color: admin.isEnabled ? Colors.green : Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  admin.isEnabled ? 'Active' : 'Inactive',
                                                  style: TextStyle(
                                                    color: admin.isEnabled ? Colors.green : Colors.red,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!admin.isVerified) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.warning,
                                                    size: 12,
                                                    color: Colors.orange[700],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Unverified',
                                                    style: TextStyle(
                                                      color: Colors.orange[700],
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
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
                            _buildOverviewTab(admin),
                            // Permissions Tab
                            _buildPermissionsTab(admin),
                            // Activity Log Tab
                            _buildActivityLogTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverviewTab(AdminModel admin) {
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
                  '#${shortUserId(admin.id)}',
                  Icons.fingerprint,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  'Created Date',
                 DateFormatter.formatDateTime(admin.createdAt),
                  Icons.calendar_today,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  'Verification Status',
                  admin.isVerified
                      ? 'Verified'
                      : 'Pending',
                  admin.isVerified
                      ? Icons.verified_user
                      : Icons.pending,
                  admin.isVerified
                      ? Colors.green
                      : Colors.amber,
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
                _buildDetailRow('Email', admin.email, Icons.email),
                const Divider(height: 24),
                _buildDetailRow('Phone','Not provided', Icons.phone), // admin.phone ??
                const Divider(height: 24),
                _buildDetailRow('Department', 'Not assigned', Icons.business),  //admin.department ??
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
                _buildActivitySummaryItem(
                  'Last Login',
                  '${DateFormatter.formatDateTime(admin.lastLogin)} (${_controller.formatDateTime(admin.lastLogin)})',
                  Icons.login,
                ),

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

  Widget _buildPermissionsTab(AdminModel admin) {
    final groupedPermissions = _controller.getGroupedPermissions();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header Card
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Role-Based Permissions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Permissions inherited from ${_controller.formatRole(admin.role)} role',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _controller.getRoleColor(admin.role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _controller.getRoleColor(admin.role).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield,
                        size: 16,
                        color: _controller.getRoleColor(admin.role),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _controller.formatRole(admin.role),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _controller.getRoleColor(admin.role),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Permission Groups
          if (groupedPermissions.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
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
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No permissions assigned',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...groupedPermissions.entries.map((entry) {
              final groupKey = entry.key;
              final permissions = entry.value;
              final group = PermissionGroups.groups[groupKey];

              if (group == null) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        group.icon,
                        color: const Color(0xFF7C3AED),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${permissions.length} permission${permissions.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    initiallyExpanded: false,
                    children: permissions.map((permission) =>
                        _buildPermissionItem(permission)
                    ).toList(),
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(String permission) {
    final permissionName = PermissionHelper.getPermissionName(permission);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.check,
              color: Colors.green,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permissionName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



// Updated _buildActivityLogTab method
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
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilterChip(
                    label: Text(filter),
                      selected: _controller.selectedLogFilter == filter,
                    onSelected: (selected) {
                      _controller.selectedLogFilter = filter;
                    },
                    selectedColor: const Color(0xFF7C3AED).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF7C3AED),
                    labelStyle: TextStyle(
                      color: _controller.selectedLogFilter == filter
                          ? const Color(0xFF7C3AED)
                          : Colors.grey[700], // Also update this condition
                    ),
                  ),
                );
              }).toList(),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _controller.loadActivityLogs(widget.adminId),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),

        // Activity Log List with Details Panel
        Expanded(
          child: Row(
            children: [
              // Main log list
              Expanded(
                flex: _showDetailsPanel ? 6 : 10,
                child: _controller.isLoadingLogs
                    ? const Center(child: CircularProgressIndicator())
                    : _controller.filteredLogs.isEmpty
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
                  itemCount: _controller.filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = _controller.filteredLogs[index];
                    return _buildLogItemWithSelection(log);
                  },
                ),
              ),

              // Resizable divider
              if (_showDetailsPanel)
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _detailsPanelWidth = (_detailsPanelWidth - details.delta.dx)
                            .clamp(_minPanelWidth, _maxPanelWidth);
                      });
                    },
                    child: Container(
                      width: 8,
                      color: Colors.grey[200],
                      child: Center(
                        child: Container(
                          width: 2,
                          height: 30,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),

              // Details Panel
              if (_showDetailsPanel)
                Container(
                  width: _detailsPanelWidth,
                  color: Colors.white,
                  child: _buildDetailsPanel(),
                ),
            ],
          ),
        ),
      ],
    );
  }


// Updated log item with selection capability
  Widget _buildLogItemWithSelection(AdminActivityLog log) {
    final icon = _controller.getLogIcon(log.action);
    final color = _controller.getLogColor(log.action);
    final isSelected = _selectedLog?.id == log.id;
    final hasDetails = log.details != null && log.details!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: const Color(0xFF7C3AED), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: InkWell(
        onTap: hasDetails ? () => _selectLog(log) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                    if (hasDetails) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${log.details!.length} detail${log.details!.length > 1 ? 's' : ''} available',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Selected',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF7C3AED),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
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
              if (hasDetails) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: isSelected ? const Color(0xFF7C3AED) : Colors.grey[400],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

// Method to select a log and show details panel
  void _selectLog(AdminActivityLog log) {
    setState(() {
      _selectedLog = log;
      _showDetailsPanel = true;
    });
  }

// Details panel widget
  Widget _buildDetailsPanel() {
    if (_selectedLog == null) return const SizedBox();

    final log = _selectedLog!;
    final icon = _controller.getLogIcon(log.action);
    final color = _controller.getLogColor(log.action);

    return Column(
      children: [
        // Panel Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Activity Details',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showDetailsPanel = false;
                        _selectedLog = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                log.action,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, MMM d, y • h:mm:ss a').format(log.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        // Panel Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log.details != null && log.details!.isNotEmpty) ...[
                  Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...log.details!.entries.map((entry) => Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: SelectableText(
                            entry.value?.toString() ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        Icon(
                          Icons.info_outline,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No additional details available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
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


  void _showEditDialog() {
    // Implement edit dialog
  }

  void _showResetPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Consumer<AdminDetailsController>(
          builder: (context, controller, child) {
            if (controller.hasData) {
              return Text('Send password reset email to ${controller.admin!.email}?');
            }
            return const Text('Loading admin data...');
          },
        ),
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
    // This would need to be implemented in the controller
    // For now, showing a placeholder implementation
    final controller = _controller;
    if (controller.hasData) {
      final currentStatus = controller.admin!.isEnabled;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentStatus
                ? 'Admin would be activated (implement in controller)'
                : 'Admin would be deactivated (implement in controller)',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }
}