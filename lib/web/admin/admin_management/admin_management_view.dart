// admin_management_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondsight/view/widgets/dateTime_utils.dart';
import '../../../model/admin_model.dart';
import '../../../view/widgets/user_utils.dart';
import '../services/permissions_guard.dart';
import '../services/permissions_manager.dart';
import '../services/admin_auth_provider.dart';
import '../widget/topbar.dart';
import 'admin_addition.dart';
import 'admin_details.dart';
import 'admin_management_controller.dart';

class AdminManagementPage extends StatefulWidget {
  const AdminManagementPage({Key? key}) : super(key: key);

  @override
  State<AdminManagementPage> createState() => _AdminManagementPageState();
}

class _AdminManagementPageState extends State<AdminManagementPage> {
  final _searchController = TextEditingController();
  String _selectedRole = 'All';
  String _searchQuery = '';
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  bool _selectAll = false;
  List<String> _selectedAdmins = [];
  final AdminController _controller = AdminController();

  @override
  Widget build(BuildContext context) {
    return PermissionRoute(
      requiredPermissions: [AdminPermissions.viewAdmins],
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  // Top Bar
                  const CustomTopBar(
                    title: 'Admin Management',
                  ),

                  // Main Content
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(20),
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
                        children: [
                          // Search & Add Admin Button
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Search admin...',
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 20),
                                PermissionButton(
                                  requiredPermissions: [AdminPermissions.createAdmins],
                                  onPressed: () => _showCreateAdminDialog(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.add),
                                      SizedBox(width: 8),
                                      Text('Add Admin'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Role Filter Tabs
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                _buildFilterTab('All'),
                                const SizedBox(width: 20),
                                _buildFilterTab('Super Admin'),
                                const SizedBox(width: 20),
                                _buildFilterTab('Admin'),
                                const SizedBox(width: 20),
                                _buildFilterTab('Manager'),
                                const SizedBox(width: 20),
                                _buildFilterTab('Support'),
                                const SizedBox(width: 20),
                                _buildFilterTab('Viewer'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Admin Table
                          Expanded(
                            child: _buildAdminTable(),
                          ),

                          // Pagination
                          _buildPagination(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String title) {
    final isActive = _selectedRole == title;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = title;
          _currentPage = 1;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF7C3AED) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFF7C3AED) : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAdminTable() {



    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getFilteredAdmins(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No admin data found.'));
        }

        final admins = snapshot.data!;
        final totalPages = (admins.length / _itemsPerPage).ceil();
        final startIndex = (_currentPage - 1) * _itemsPerPage;
        final endIndex = (startIndex + _itemsPerPage).clamp(0, admins.length);
        final currentAdmins = admins.sublist(startIndex, endIndex);


        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(
                label: SizedBox(
                  width: 30,
                  child: Checkbox(
                    value: _selectAll,
                    onChanged: (value) {
                      setState(() {
                        _selectAll = value!;
                        if (_selectAll) {
                          _selectedAdmins = currentAdmins.map((admin) => admin['id'] as String).toList();
                        } else {
                          _selectedAdmins.clear();
                        }
                      });
                    },
                  ),
                ),
              ),
              const DataColumn(label: Text('Admin ID')),
              const DataColumn(label: Text('Name')),
              const DataColumn(label: Text('Email')),
              const DataColumn(label: Text('Role')),
              const DataColumn(label: Text('Status')),
              const DataColumn(label: Text('Last Active')),
              const DataColumn(label: Text('Created')),
              const DataColumn(label: Text('Action')),
            ],
            rows: currentAdmins.map((admin) {
              print('DEBUG → Admin: ${admin['id']} '
                  '| lastActive: ${admin['lastActive']} '
                  '| createdAt: ${admin['createdAt']}');
              return DataRow(
                cells: [
                  DataCell(
                    Checkbox(
                      value: _selectedAdmins.contains(admin['id']),
                      onChanged: (value) {
                        setState(() {
                          if (value!) {
                            _selectedAdmins.add(admin['id']);
                          } else {
                            _selectedAdmins.remove(admin['id']);
                          }
                        });
                      },
                    ),
                  ),
                  DataCell(Text('#${shortUserId(admin['id'])}')),
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF7C3AED).withOpacity(0.1),
                          child: Text(
                            admin['name'][0].toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF7C3AED),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(admin['name']),
                      ],
                    ),
                  ),
                  DataCell(Text(admin['email'])),

                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRoleColor(admin['role']).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _controller.formatRole(admin['role']),
                        style: TextStyle(
                          color: _getRoleColor(admin['role']),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: admin['isActive']
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        admin['isActive'] ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: admin['isActive'] ? Colors.green : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(admin['lastActive'])
                  ),
                  DataCell(Text(DateFormatter.formatDate(admin['createdAt']))
                  ), // You may replace this with actual logic
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminDetailsPage(adminId: admin['id']),
                              ),
                            );
                          },
                          tooltip: 'View Details',
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _showEditAdminDialog(context, admin); // Add await here
                            } else if (value == 'toggle_status') {
                              // Use the new toggle function
                              final success = await _controller.toggleAdminStatus(
                                  admin['id'],
                                  admin['isActive'],
                                  context
                              );

                              if (success) {
                                // Refresh the table
                                setState(() {});
                              }
                            } else if (value == 'deactivate') {
                              // Use the dedicated deactivate function
                              final success = await _controller.deactivateAdmin(admin['id'], context);

                              if (success) {
                                // Refresh the table
                                setState(() {});
                              }
                            } else if (value == 'activate') {
                              // Use the dedicated activate function
                              final success = await _controller.activateAdmin(admin['id'], context);

                              if (success) {
                                // Refresh the table
                                setState(() {});
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit Admin'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: admin['isActive'] ? 'deactivate' : 'activate',
                              child: Row(
                                children: [
                                  Icon(
                                    admin['isActive'] ? Icons.block : Icons.check_circle,
                                    size: 16,
                                    color: admin['isActive'] ? Colors.orange : Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    admin['isActive'] ? 'Deactivate' : 'Activate',
                                    style: TextStyle(
                                      color: admin['isActive'] ? Colors.orange : Colors.green,
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
              );
            }).toList(),
          ),
        );
      },
    );
  }


  Widget _buildPagination() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getFilteredAdmins(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No admin data available.'));
        }

        final admins = snapshot.data!;
        final totalPages = (admins.length / _itemsPerPage).ceil();
        final startIndex = (_currentPage - 1) * _itemsPerPage;
        final endIndex = (startIndex + _itemsPerPage).clamp(0, admins.length);

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Showing ${startIndex + 1} to $endIndex of ${admins.length} items'),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 1
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  ...List.generate(
                    totalPages > 5 ? 5 : totalPages,
                        (index) {
                      final page = index + 1;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ElevatedButton(
                          onPressed: () => setState(() => _currentPage = page),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentPage == page
                                ? const Color(0xFF7C3AED)
                                : Colors.grey[300],
                            minimumSize: const Size(40, 40),
                          ),
                          child: Text(
                            '$page',
                            style: TextStyle(
                              color: _currentPage == page ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < totalPages
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }



  Future<List<Map<String, dynamic>>> _getFilteredAdmins() async {
    List<Map<String, dynamic>> admins = await _controller.getAdmins();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      admins = admins.where((admin) {
        return admin['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
            admin['email'].toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filter by role
    if (_selectedRole != 'All') {
      admins = admins.where((admin) {
        return _controller.formatRole(admin['role']) == _selectedRole;
      }).toList();
    }

    return admins;
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


  void _showCreateAdminDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateAdminDialog(),
    );
  }

  Future<void> _showEditAdminDialog(BuildContext context, Map<String, dynamic> admin) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditAdminDialog(
        admin: admin,
        controller: _controller,
      ),
    );

    // If the dialog returned true (indicating successful update), refresh the page
    if (result == true) {
      setState(() {
        // This will trigger a rebuild and refresh the admin table
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}


