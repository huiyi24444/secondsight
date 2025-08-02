// admin_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/permissions_guard.dart';
import '../services/permissions_manager.dart';
import '../services/admin_auth_provider.dart';

class AdminManagementPage extends StatefulWidget {
  const AdminManagementPage({Key? key}) : super(key: key);

  @override
  State<AdminManagementPage> createState() => _AdminManagementPageState();
}

class _AdminManagementPageState extends State<AdminManagementPage> {
  final _searchController = TextEditingController();
  String _selectedRole = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return PermissionRoute(
      requiredPermissions: [AdminPermissions.viewAdmins],
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Row(
          children: [
            // Main Content
            Expanded(
              child: Column(
                children: [
                  // Header
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Admin Management',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            PermissionButton(
                              requiredPermissions: [AdminPermissions.createAdmins],
                              onPressed: () => _showCreateAdminDialog(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.add, size: 18),
                                  SizedBox(width: 8),
                                  Text('Add New Admin'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage admin users and their permissions',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search and Filters
                  Container(
                    color: Colors.white,
                    margin: const EdgeInsets.only(top: 1),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Search
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search by name or email...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Role Filter
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedRole,
                              items: [
                                const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All Roles'),
                                ),
                                ...AdminRoles.roles.entries.map((entry) {
                                  return DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value.name),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedRole = value!;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Admin List
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildAdminList(),
                    ),
                  ),
                ],
              ),
            ),

            // Stats Sidebar
            Container(
              width: 300,
              color: Colors.white,
              child: _buildStatsSidebar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminList() {
    // Mock data - replace with actual data from your backend
    final admins = _getMockAdmins();

    final filteredAdmins = admins.where((admin) {
      final matchesSearch = admin['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          admin['email'].toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _selectedRole == 'all' || admin['role'] == _selectedRole;
      return matchesSearch && matchesRole;
    }).toList();

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'ADMIN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'ROLE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'STATUS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'LAST ACTIVE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 100),
            ],
          ),
        ),

        // Admin Rows
        Expanded(
          child: ListView.builder(
            itemCount: filteredAdmins.length,
            itemBuilder: (context, index) {
              final admin = filteredAdmins[index];
              return _buildAdminRow(admin);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdminRow(Map<String, dynamic> admin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Row(
        children: [
          // Admin Info
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Text(
                    admin['name'][0].toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      admin['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      admin['email'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Role
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getRoleColor(admin['role']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                AdminRoles.roles[admin['role']]?.name ?? admin['role'],
                style: TextStyle(
                  fontSize: 12,
                  color: _getRoleColor(admin['role']),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Status
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: admin['isActive'] ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  admin['isActive'] ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 14,
                    color: admin['isActive'] ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),

          // Last Active
          Expanded(
            flex: 2,
            child: Text(
              admin['lastActive'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),

          // Actions
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PermissionIconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  requiredPermissions: [AdminPermissions.editAdmins],
                  onPressed: () => _showEditAdminDialog(context, admin),
                  tooltip: 'Edit Admin',
                ),
                PermissionIconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  requiredPermissions: [AdminPermissions.deleteAdmins],
                  onPressed: () => _showDeleteConfirmation(context, admin),
                  tooltip: 'Delete Admin',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSidebar() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Statistics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Total Admins
          _buildStatCard(
            icon: Icons.people,
            title: 'Total Admins',
            value: '24',
            color: Colors.blue,
          ),
          const SizedBox(height: 16),

          // Active Admins
          _buildStatCard(
            icon: Icons.check_circle,
            title: 'Active Admins',
            value: '18',
            color: Colors.green,
          ),
          const SizedBox(height: 16),

          // Inactive Admins
          _buildStatCard(
            icon: Icons.cancel,
            title: 'Inactive Admins',
            value: '6',
            color: Colors.red,
          ),
          const SizedBox(height: 32),

          // Role Distribution
          const Text(
            'Role Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...AdminRoles.roles.entries.map((entry) {
            final count = _getMockAdmins().where((a) => a['role'] == entry.key).length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.value.name,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(entry.key).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        color: _getRoleColor(entry.key),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateAdminDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateAdminDialog(),
    );
  }

  void _showEditAdminDialog(BuildContext context, Map<String, dynamic> admin) {
    showDialog(
      context: context,
      builder: (context) => EditAdminDialog(admin: admin),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> admin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Admin'),
        content: Text('Are you sure you want to delete ${admin['name']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement delete logic
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${admin['name']} has been deleted')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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

  List<Map<String, dynamic>> _getMockAdmins() {
    return [
      {
        'id': '1',
        'name': 'John Doe',
        'email': 'john@example.com',
        'role': 'super_admin',
        'isActive': true,
        'lastActive': '2 minutes ago',
      },
      {
        'id': '2',
        'name': 'Jane Smith',
        'email': 'jane@example.com',
        'role': 'admin',
        'isActive': true,
        'lastActive': '1 hour ago',
      },
      {
        'id': '3',
        'name': 'Mike Johnson',
        'email': 'mike@example.com',
        'role': 'manager',
        'isActive': true,
        'lastActive': '3 hours ago',
      },
      {
        'id': '4',
        'name': 'Sarah Williams',
        'email': 'sarah@example.com',
        'role': 'support',
        'isActive': false,
        'lastActive': '2 days ago',
      },
      {
        'id': '5',
        'name': 'Tom Brown',
        'email': 'tom@example.com',
        'role': 'viewer',
        'isActive': true,
        'lastActive': '5 hours ago',
      },
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Create Admin Dialog
class CreateAdminDialog extends StatefulWidget {
  const CreateAdminDialog({Key? key}) : super(key: key);

  @override
  State<CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends State<CreateAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'viewer';
  bool _isActive = true;

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
                    'Create New Admin',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password Field
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Role Selection
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: AdminRoles.roles.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Active Status
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text('Admin can access the system immediately'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Implement create logic
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Admin created successfully')),
                        );
                      }
                    },
                    child: const Text('Create Admin'),
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

// Edit Admin Dialog
class EditAdminDialog extends StatefulWidget {
  final Map<String, dynamic> admin;

  const EditAdminDialog({Key? key, required this.admin}) : super(key: key);

  @override
  State<EditAdminDialog> createState() => _EditAdminDialogState();
}

class _EditAdminDialogState extends State<EditAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late String _selectedRole;
  late bool _isActive;
  final List<String> _customPermissions = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.admin['name']);
    _emailController = TextEditingController(text: widget.admin['email']);
    _selectedRole = widget.admin['role'];
    _isActive = widget.admin['isActive'];
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(32),
        child: Column(
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column - Basic Info
                  Expanded(
                    flex: 1,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Basic Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Name Field
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Role Selection
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              border: OutlineInputBorder(),
                            ),
                            items: AdminRoles.roles.entries.map((entry) {
                              return DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedRole = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Active Status
                          SwitchListTile(
                            title: const Text('Active'),
                            subtitle: const Text('Admin can access the system'),
                            value: _isActive,
                            onChanged: (value) {
                              setState(() {
                                _isActive = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 32),

                  // Right Column - Permissions
                  Expanded(
                    flex: 1,
                    child: PermissionGuard(
                      requiredPermissions: [AdminPermissions.managePermissions],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Custom Permissions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Override role permissions for this admin',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),

                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: PermissionGroups.groups.entries.map((entry) {
                                  return _buildPermissionGroup(
                                    entry.value.name,
                                    entry.value.icon,
                                    entry.value.permissions,
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      fallback: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.lock, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Manage Permissions permission required',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      // Implement update logic
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Admin updated successfully')),
                      );
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionGroup(String name, IconData icon, List<String> permissions) {
    return ExpansionTile(
      leading: Icon(icon, size: 20),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children: permissions.map((permission) {
        final isChecked = _customPermissions.contains(permission);
        return CheckboxListTile(
          title: Text(
            PermissionHelper.getPermissionName(permission),
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: Text(
            PermissionHelper.getPermissionDescription(permission),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          value: isChecked,
          onChanged: (value) {
            setState(() {
              if (value!) {
                _customPermissions.add(permission);
              } else {
                _customPermissions.remove(permission);
              }
            });
          },
          dense: true,
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}

// Admin Activity Log Widget
class AdminActivityLog extends StatelessWidget {
  final String adminId;

  const AdminActivityLog({Key? key, required this.adminId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock activity data
    final activities = [
      {
        'action': 'Updated product pricing',
        'timestamp': '2 hours ago',
        'icon': Icons.edit,
        'color': Colors.blue,
      },
      {
        'action': 'Processed order #1234',
        'timestamp': '5 hours ago',
        'icon': Icons.shopping_cart,
        'color': Colors.green,
      },
      {
        'action': 'Deleted expired promotion',
        'timestamp': '1 day ago',
        'icon': Icons.delete,
        'color': Colors.red,
      },
      {
        'action': 'Created new category',
        'timestamp': '2 days ago',
        'icon': Icons.add,
        'color': Colors.purple,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const Divider(height: 1),
          ...activities.map((activity) => ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (activity['color'] as Color).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                activity['icon'] as IconData,
                size: 16,
                color: activity['color'] as Color,
              ),
            ),
            title: Text(
              activity['action'] as String,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              activity['timestamp'] as String,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            dense: true,
          )),
        ],
      ),
    );
  }
}

// Bulk Actions Dialog
class BulkActionsDialog extends StatefulWidget {
  final List<String> selectedAdminIds;

  const BulkActionsDialog({Key? key, required this.selectedAdminIds}) : super(key: key);

  @override
  State<BulkActionsDialog> createState() => _BulkActionsDialogState();
}

class _BulkActionsDialogState extends State<BulkActionsDialog> {
  String _selectedAction = 'activate';
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bulk Actions',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.selectedAdminIds.length} admins selected',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Action Selection
            RadioListTile<String>(
              title: const Text('Activate Accounts'),
              subtitle: const Text('Enable selected admin accounts'),
              value: 'activate',
              groupValue: _selectedAction,
              onChanged: (value) {
                setState(() {
                  _selectedAction = value!;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Deactivate Accounts'),
              subtitle: const Text('Disable selected admin accounts'),
              value: 'deactivate',
              groupValue: _selectedAction,
              onChanged: (value) {
                setState(() {
                  _selectedAction = value!;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Change Role'),
              subtitle: const Text('Update role for selected admins'),
              value: 'change_role',
              groupValue: _selectedAction,
              onChanged: (value) {
                setState(() {
                  _selectedAction = value!;
                });
              },
            ),

            // Role Selection (if changing role)
            if (_selectedAction == 'change_role') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Select New Role',
                  border: OutlineInputBorder(),
                ),
                items: AdminRoles.roles.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value;
                  });
                },
              ),
            ],

            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_selectedAction == 'change_role' && _selectedRole == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a role')),
                      );
                      return;
                    }
                    // Implement bulk action logic
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bulk action completed successfully')),
                    );
                  },
                  child: const Text('Apply Action'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Admin Details View
class AdminDetailsView extends StatelessWidget {
  final Map<String, dynamic> admin;

  const AdminDetailsView({Key? key, required this.admin}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Text(
                  admin['name'][0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 32,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      admin['name'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      admin['email'],
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: admin['isActive'] ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  admin['isActive'] ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: admin['isActive'] ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Info Grid
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Role',
                  AdminRoles.roles[admin['role']]?.name ?? admin['role'],
                  Icons.badge,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  'Last Active',
                  admin['lastActive'],
                  Icons.access_time,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  'Created',
                  '3 months ago',
                  Icons.calendar_today,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Permissions Section
          const Text(
            'Permissions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PermissionHelper.getPermissionsForRole(admin['role']).map((permission) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  PermissionHelper.getPermissionName(permission),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}