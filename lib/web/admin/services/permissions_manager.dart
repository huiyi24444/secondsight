// permission_manager.dart
import 'package:flutter/material.dart';

/// Defines all available permissions in the system
class AdminPermissions {
  // User Management
  static const String viewUsers = 'view_users';
  static const String createUsers = 'create_users';
  static const String editUsers = 'edit_users';

  // Product Management
  static const String viewDashboard = 'view_dashboard';
  static const String viewProducts = 'view_products';
  static const String createProducts = 'create_products';
  static const String editProducts = 'edit_products';
  static const String deleteProducts = 'delete_products';

  // Order Management
  static const String viewOrders = 'view_orders';
  static const String processOrders = 'process_orders';
  static const String cancelOrders = 'cancel_orders';

  //static const String refundOrders = 'refund_orders';

  static const String viewReturns = 'view_returns';
  static const String createReturns = 'create_returns';
  static const String editReturns = 'edit_returns';
  static const String cancelReturns = 'delete_returns';

  // Category Management
  static const String viewCategories = 'view_categories';
  static const String manageCategories = 'manage_categories';

  // Customer Support
  static const String viewConversations = 'view_conversations';

  // Analytics & Reports
  static const String viewAnalytics = 'view_analytics';
  static const String exportReports = 'export_reports';

  // Admin Management
  static const String viewAdmins = 'view_admins';
  static const String createAdmins = 'create_admins';
  static const String editAdmins = 'edit_admins';
  static const String managePermissions = 'manage_permissions';

  // System Settings
  //static const String viewSettings = 'view_settings';
  //static const String editSettings = 'edit_settings';

  // Financial
  //static const String viewFinancials = 'view_financials';
  //static const String processPayments = 'process_payments';

  // Marketing
  //static const String viewMarketing = 'view_marketing';
  //static const String managePromotions = 'manage_promotions';
  //static const String sendNotifications = 'send_notifications';
}

/// Defines admin roles and their default permissions
class AdminRoles {
  static const Map<String, AdminRole> roles = {
    'super_admin': AdminRole(
      name: 'Super Admin',
      description: 'Full system access',
      permissions: [
        // All permissions
        AdminPermissions.viewUsers,
        AdminPermissions.createUsers,
        AdminPermissions.editUsers,
        AdminPermissions.viewDashboard,
        AdminPermissions.viewProducts,
        AdminPermissions.createProducts,
        AdminPermissions.editProducts,
        AdminPermissions.deleteProducts,
        AdminPermissions.viewOrders,
        AdminPermissions.processOrders,
        AdminPermissions.cancelOrders,
        AdminPermissions.viewReturns,
        AdminPermissions.createReturns,
        AdminPermissions.editReturns,
        AdminPermissions.cancelReturns,
        AdminPermissions.viewCategories,
        AdminPermissions.manageCategories,
        AdminPermissions.viewConversations,
        AdminPermissions.viewAnalytics,
        AdminPermissions.exportReports,
        AdminPermissions.viewAdmins,
        AdminPermissions.createAdmins,
        AdminPermissions.editAdmins,
        AdminPermissions.managePermissions,
      ],
    ),
    'admin': AdminRole(
      name: 'Admin',
      description: 'General administrative access',
      permissions: [
        AdminPermissions.viewUsers,
        AdminPermissions.createUsers,
        AdminPermissions.editUsers,
        AdminPermissions.viewDashboard,
        AdminPermissions.viewProducts,
        AdminPermissions.createProducts,
        AdminPermissions.editProducts,
        AdminPermissions.deleteProducts,
        AdminPermissions.viewOrders,
        AdminPermissions.processOrders,
        AdminPermissions.cancelOrders,
        AdminPermissions.viewReturns,
        AdminPermissions.createReturns,
        AdminPermissions.editReturns,
        AdminPermissions.cancelReturns,
        AdminPermissions.viewCategories,
        AdminPermissions.manageCategories,
        AdminPermissions.viewConversations,
        AdminPermissions.viewAnalytics,
        AdminPermissions.exportReports,
      ],
    ),
    'manager': AdminRole(
      name: 'Manager',
      description: 'Product and order management',
      permissions: [
        AdminPermissions.viewUsers,
        AdminPermissions.viewProducts,
        AdminPermissions.editProducts,
        AdminPermissions.viewOrders,
        AdminPermissions.processOrders,
        AdminPermissions.viewCategories,
        AdminPermissions.viewAnalytics,
      ],
    ),
    'support': AdminRole(
      name: 'Customer Support',
      description: 'Customer service access',
      permissions: [
        AdminPermissions.viewUsers,
        AdminPermissions.viewProducts,
        AdminPermissions.viewOrders,
        AdminPermissions.cancelOrders,
        AdminPermissions.viewConversations,
      ],
    ),
    'viewer': AdminRole(
      name: 'Viewer',
      description: 'Read-only access',
      permissions: [
        AdminPermissions.viewUsers,
        AdminPermissions.viewProducts,
        AdminPermissions.viewOrders,
        AdminPermissions.viewCategories,
        AdminPermissions.viewAnalytics,
      ],
    ),
  };
}

class AdminRole {
  final String name;
  final String description;
  final List<String> permissions;

  const AdminRole({
    required this.name,
    required this.description,
    required this.permissions,
  });
}

/// Permission groups for UI organization
class PermissionGroups {
  static const Map<String, PermissionGroup> groups = {
    'users': PermissionGroup(
      name: 'User Management',
      icon: Icons.people,
      permissions: [
        AdminPermissions.viewUsers,
        AdminPermissions.createUsers,
        AdminPermissions.editUsers,
      ],
    ),
    'products': PermissionGroup(
      name: 'Product Management',
      icon: Icons.inventory,
      permissions: [
        AdminPermissions.viewProducts,
        AdminPermissions.createProducts,
        AdminPermissions.editProducts,
        AdminPermissions.deleteProducts,
      ],
    ),
    'orders': PermissionGroup(
      name: 'Order Management',
      icon: Icons.shopping_cart,
      permissions: [
        AdminPermissions.viewOrders,
        AdminPermissions.processOrders,
        AdminPermissions.cancelOrders,
      ],
    ),
    'returns': PermissionGroup(
      name: 'Return Management',
      icon: 	Icons.autorenew,
      permissions: [
        AdminPermissions.viewReturns,
        AdminPermissions.createReturns,
        AdminPermissions.editReturns,
        AdminPermissions.cancelReturns,
      ],
    ),
    'support': PermissionGroup(
      name: 'Customer Support',
      icon: Icons.support_agent,
      permissions: [
        AdminPermissions.viewConversations,
      ],
    ),
    'analytics': PermissionGroup(
      name: 'Analytics & Reports',
      icon: Icons.analytics,
      permissions: [
        AdminPermissions.viewAnalytics,
        AdminPermissions.exportReports,
      ],
    ),
    'admins': PermissionGroup(
      name: 'Admin Management',
      icon: Icons.admin_panel_settings,
      permissions: [
        AdminPermissions.viewAdmins,
        AdminPermissions.createAdmins,
        AdminPermissions.editAdmins,
        AdminPermissions.managePermissions,
      ],
    ),
    'system': PermissionGroup(
      name: 'System Settings',
      icon: Icons.settings,
      permissions: [],
    ),
    'financial': PermissionGroup(
      name: 'Financial',
      icon: Icons.attach_money,
      permissions: [],
    ),
    'marketing': PermissionGroup(
      name: 'Marketing',
      icon: Icons.campaign,
      permissions: [],
    ),
  };
}

class PermissionGroup {
  final String name;
  final IconData icon;
  final List<String> permissions;

  const PermissionGroup({
    required this.name,
    required this.icon,
    required this.permissions,
  });
}

/// Helper class for permission-related operations
class PermissionHelper {
  /// Get human-readable name for a permission
  static String getPermissionName(String permission) {
    final Map<String, String> permissionNames = {
      // Users
      AdminPermissions.viewUsers: 'View Users',
      AdminPermissions.createUsers: 'Create Users',
      AdminPermissions.editUsers: 'Edit Users',

      // Products
      AdminPermissions.viewProducts: 'View Products',
      AdminPermissions.createProducts: 'Create Products',
      AdminPermissions.editProducts: 'Edit Products',
      AdminPermissions.deleteProducts: 'Delete Products',

      // Orders
      AdminPermissions.viewOrders: 'View Orders',
      AdminPermissions.processOrders: 'Process Orders',
      AdminPermissions.cancelOrders: 'Cancel Orders',

      //returns
      AdminPermissions.viewReturns: 'View Returns',
      AdminPermissions.createReturns: 'Create Returns',
      AdminPermissions.editReturns: 'Edit Returns',
      AdminPermissions.cancelReturns: 'Cancel Returns',


      // Categories
      AdminPermissions.viewCategories: 'View Categories',
      AdminPermissions.manageCategories: 'Manage Categories',

      // Analytics
      AdminPermissions.viewAnalytics: 'View Analytics',
      AdminPermissions.exportReports: 'Export Reports',

      // Admins
      AdminPermissions.viewAdmins: 'View Admins',
      AdminPermissions.createAdmins: 'Create Admins',
      AdminPermissions.editAdmins: 'Edit Admins',
      AdminPermissions.managePermissions: 'Manage Permissions',
    };

    return permissionNames[permission] ?? permission;
  }

  /// Check if a list of permissions includes a specific permission
  static bool hasPermission(List<String> userPermissions, String permission) {
    return userPermissions.contains(permission);
  }

  /// Check if a list of permissions includes all required permissions
  static bool hasAllPermissions(
    List<String> userPermissions,
    List<String> requiredPermissions,
  ) {
    return requiredPermissions.every(
      (permission) => userPermissions.contains(permission),
    );
  }

  /// Check if a list of permissions includes any of the required permissions
  static bool hasAnyPermission(
    List<String> userPermissions,
    List<String> requiredPermissions,
  ) {
    return requiredPermissions.any(
      (permission) => userPermissions.contains(permission),
    );
  }

  /// Get permissions for a role
  static List<String> getPermissionsForRole(String roleId) {
    return AdminRoles.roles[roleId]?.permissions ?? [];
  }

  /// Get all available permissions
  static List<String> getAllPermissions() {
    final permissions = <String>[];
    PermissionGroups.groups.values.forEach((group) {
      permissions.addAll(group.permissions);
    });
    return permissions.toSet().toList(); // Remove duplicates
  }
}
