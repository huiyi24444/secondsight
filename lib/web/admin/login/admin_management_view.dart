// admin_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/permissions_guard.dart';
import '../services/permissions_manager.dart';
import '../services/admin_auth_provider.dart';
import '../widget/topbar.dart';

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
    final admins = _getFilteredAdmins();
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
              DataCell(Text('#${admin['id']}')),
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
                    _formatRole(admin['role']),
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
              DataCell(Text(admin['lastActive'])),
              DataCell(Text('3 months ago')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined),
                      onPressed: () => _showAdminDetails(context, admin),
                      tooltip: 'View Details',
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditAdminDialog(context, admin);
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(context, admin);
                        } else if (value == 'toggle_status') {
                          setState(() {
                            admin['isActive'] = !admin['isActive'];
                          });
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit Admin'),
                        ),
                        PopupMenuItem(
                          value: 'toggle_status',
                          child: Text(admin['isActive'] ? 'Deactivate' : 'Activate'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Admin', style: TextStyle(color: Colors.red)),
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
  }

  Widget _buildPagination() {
    final admins = _getFilteredAdmins();
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
                    ? () {
                  setState(() {
                    _currentPage--;
                  });
                }
                    : null,
              ),
              ...List.generate(
                totalPages > 5 ? 5 : totalPages,
                    (index) {
                  final page = index + 1;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _currentPage = page;
                        });
                      },
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
                    ? () {
                  setState(() {
                    _currentPage++;
                  });
                }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredAdmins() {
    var admins = _getMockAdmins();

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
        return _formatRole(admin['role']) == _selectedRole;
      }).toList();
    }

    return admins;
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

  void _showAdminDetails(BuildContext context, Map<String, dynamic> admin) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Admin Details',
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
              AdminDetailsView(admin: admin),
            ],
          ),
        ),
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
      {
        'id': '6',
        'name': 'Alice Johnson',
        'email': 'alice@example.com',
        'role': 'admin',
        'isActive': true,
        'lastActive': '30 minutes ago',
      },
      {
        'id': '7',
        'name': 'Bob Wilson',
        'email': 'bob@example.com',
        'role': 'manager',
        'isActive': true,
        'lastActive': '2 hours ago',
      },
      {
        'id': '8',
        'name': 'Carol Davis',
        'email': 'carol@example.com',
        'role': 'support',
        'isActive': true,
        'lastActive': '45 minutes ago',
      },
      {
        'id': '9',
        'name': 'David Lee',
        'email': 'david@example.com',
        'role': 'viewer',
        'isActive': false,
        'lastActive': '3 days ago',
      },
      {
        'id': '10',
        'name': 'Emma Martinez',
        'email': 'emma@example.com',
        'role': 'admin',
        'isActive': true,
        'lastActive': '15 minutes ago',
      },
      {
        'id': '11',
        'name': 'Frank Taylor',
        'email': 'frank@example.com',
        'role': 'super_admin',
        'isActive': true,
        'lastActive': '1 hour ago',
      },
      {
        'id': '12',
        'name': 'Grace Anderson',
        'email': 'grace@example.com',
        'role': 'manager',
        'isActive': true,
        'lastActive': '4 hours ago',
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                    ),
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

// Edit Admin Dialog - Simplified version
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                    ),
                    child: const Text('Save Changes'),
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
    super.dispose();
  }
}

// Simplified Admin Details View
class AdminDetailsView extends StatelessWidget {
  final Map<String, dynamic> admin;

  const AdminDetailsView({Key? key, required this.admin}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF7C3AED).withOpacity(0.1),
              child: Text(
                admin['name'][0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 32,
                  color: Color(0xFF7C3AED),
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
      ],
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