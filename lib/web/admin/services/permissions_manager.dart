// permission_manager.dart
import 'package:flutter/material.dart';

/// Defines all available permissions in the system
class AdminPermissions {
  // User Management
  static const String viewUsers = 'view_users';
  static const String createUsers = 'create_users';
  static const String editUsers = 'edit_users';
  static const String deleteUsers = 'delete_users';

  // Product Management
  static const String viewProducts = 'view_products';
  static const String createProducts = 'create_products';
  static const String editProducts = 'edit_products';
  static const String deleteProducts = 'delete_products';

  // Order Management
  static const String viewOrders = 'view_orders';
  static const String processOrders = 'process_orders';
  static const String cancelOrders = 'cancel_orders';
  static const String refundOrders = 'refund_orders';

  // Category Management
  static const String viewCategories = 'view_categories';
  static const String manageCategories = 'manage_categories';

  // Customer Support
  static const String viewSupport = 'view_support';
  static const String respondSupport = 'respond_support';
  static const String closeSupport = 'close_support';

  // Analytics & Reports
  static const String viewAnalytics = 'view_analytics';
  static const String exportReports = 'export_reports';

  // Admin Management
  static const String viewAdmins = 'view_admins';
  static const String createAdmins = 'create_admins';
  static const String editAdmins = 'edit_admins';
  static const String deleteAdmins = 'delete_admins';
  static const String managePermissions = 'manage_permissions';

  // System Settings
  static const String viewSettings = 'view_settings';
  static const String editSettings = 'edit_settings';

  // Financial
  static const String viewFinancials = 'view_financials';
  static const String processPayments = 'process_payments';

  // Marketing
  static const String viewMarketing = 'view_marketing';
  static const String managePromotions = 'manage_promotions';
  static const String sendNotifications = 'send_notifications';
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
        AdminPermissions.deleteUsers,
        AdminPermissions.viewProducts,
        AdminPermissions.createProducts,
        AdminPermissions.editProducts,
        AdminPermissions.deleteProducts,
        AdminPermissions.viewOrders,
        AdminPermissions.processOrders,
        AdminPermissions.cancelOrders,
        AdminPermissions.refundOrders,
        AdminPermissions.viewCategories,
        AdminPermissions.manageCategories,
        AdminPermissions.viewSupport,
        AdminPermissions.respondSupport,
        AdminPermissions.closeSupport,
        AdminPermissions.viewAnalytics,
        AdminPermissions.exportReports,
        AdminPermissions.viewAdmins,
        AdminPermissions.createAdmins,
        AdminPermissions.editAdmins,
        AdminPermissions.deleteAdmins,
        AdminPermissions.managePermissions,
        AdminPermissions.viewSettings,
        AdminPermissions.editSettings,
        AdminPermissions.viewFinancials,
        AdminPermissions.processPayments,
        AdminPermissions.viewMarketing,
        AdminPermissions.managePromotions,
        AdminPermissions.sendNotifications,
      ],
    ),
    'admin': AdminRole(
      name: 'Admin',
      description: 'General administrative access',
      permissions: [
        AdminPermissions.viewUsers,
        AdminPermissions.editUsers,
        AdminPermissions.viewProducts,
        AdminPermissions.createProducts,
        AdminPermissions.editProducts,
        AdminPermissions.deleteProducts,
        AdminPermissions.viewOrders,
        AdminPermissions.processOrders,
        AdminPermissions.cancelOrders,
        AdminPermissions.refundOrders,
        AdminPermissions.viewCategories,
        AdminPermissions.manageCategories,
        AdminPermissions.viewSupport,
        AdminPermissions.respondSupport,
        AdminPermissions.closeSupport,
        AdminPermissions.viewAnalytics,
        AdminPermissions.exportReports,
        AdminPermissions.viewSettings,
        AdminPermissions.viewFinancials,
        AdminPermissions.viewMarketing,
        AdminPermissions.managePromotions,
      ],
    ),
    'manager': AdminRole(
      name: 'Manager',
      description: 'Product and order management',
      permissions: [
        AdminPermissions.viewUsers,
        AdminPermissions.viewProducts,
        AdminPermissions.createProducts,
        AdminPermissions.editProducts,
        AdminPermissions.viewOrders,
        AdminPermissions.processOrders,
        AdminPermissions.viewCategories,
        AdminPermissions.viewSupport,
        AdminPermissions.respondSupport,
        AdminPermissions.viewAnalytics,
        AdminPermissions.viewMarketing,
      ],
    ),
    'support': AdminRole(
      name: 'Customer Support',
      description: 'Customer service access',
      permissions: [
        AdminPermissions.viewUsers,
        AdminPermissions.viewProducts,
        AdminPermissions.viewOrders,
        AdminPermissions.viewSupport,
        AdminPermissions.respondSupport,
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
        AdminPermissions.viewSupport,
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
        AdminPermissions.deleteUsers,
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
        AdminPermissions.refundOrders,
      ],
    ),
    'support': PermissionGroup(
      name: 'Customer Support',
      icon: Icons.support_agent,
      permissions: [
        AdminPermissions.viewSupport,
        AdminPermissions.respondSupport,
        AdminPermissions.closeSupport,
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
        AdminPermissions.deleteAdmins,
        AdminPermissions.managePermissions,
      ],
    ),
    'system': PermissionGroup(
      name: 'System Settings',
      icon: Icons.settings,
      permissions: [
        AdminPermissions.viewSettings,
        AdminPermissions.editSettings,
      ],
    ),
    'financial': PermissionGroup(
      name: 'Financial',
      icon: Icons.attach_money,
      permissions: [
        AdminPermissions.viewFinancials,
        AdminPermissions.processPayments,
      ],
    ),
    'marketing': PermissionGroup(
      name: 'Marketing',
      icon: Icons.campaign,
      permissions: [
        AdminPermissions.viewMarketing,
        AdminPermissions.managePromotions,
        AdminPermissions.sendNotifications,
      ],
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
      AdminPermissions.deleteUsers: 'Delete Users',

      // Products
      AdminPermissions.viewProducts: 'View Products',
      AdminPermissions.createProducts: 'Create Products',
      AdminPermissions.editProducts: 'Edit Products',
      AdminPermissions.deleteProducts: 'Delete Products',

      // Orders
      AdminPermissions.viewOrders: 'View Orders',
      AdminPermissions.processOrders: 'Process Orders',
      AdminPermissions.cancelOrders: 'Cancel Orders',
      AdminPermissions.refundOrders: 'Process Refunds',

      // Categories
      AdminPermissions.viewCategories: 'View Categories',
      AdminPermissions.manageCategories: 'Manage Categories',

      // Support
      AdminPermissions.viewSupport: 'View Support Tickets',
      AdminPermissions.respondSupport: 'Respond to Support',
      AdminPermissions.closeSupport: 'Close Support Tickets',

      // Analytics
      AdminPermissions.viewAnalytics: 'View Analytics',
      AdminPermissions.exportReports: 'Export Reports',

      // Admins
      AdminPermissions.viewAdmins: 'View Admins',
      AdminPermissions.createAdmins: 'Create Admins',
      AdminPermissions.editAdmins: 'Edit Admins',
      AdminPermissions.deleteAdmins: 'Delete Admins',
      AdminPermissions.managePermissions: 'Manage Permissions',

      // Settings
      AdminPermissions.viewSettings: 'View Settings',
      AdminPermissions.editSettings: 'Edit Settings',

      // Financial
      AdminPermissions.viewFinancials: 'View Financials',
      AdminPermissions.processPayments: 'Process Payments',

      // Marketing
      AdminPermissions.viewMarketing: 'View Marketing',
      AdminPermissions.managePromotions: 'Manage Promotions',
      AdminPermissions.sendNotifications: 'Send Notifications',
    };

    return permissionNames[permission] ?? permission;
  }

  /// Get description for a permission
  static String getPermissionDescription(String permission) {
    final Map<String, String> descriptions = {
      AdminPermissions.viewUsers: 'View user profiles and account information',
      AdminPermissions.createUsers: 'Create new user accounts',
      AdminPermissions.editUsers: 'Modify user information and settings',
      AdminPermissions.deleteUsers: 'Remove user accounts from the system',

      AdminPermissions.viewProducts: 'View product listings and details',
      AdminPermissions.createProducts: 'Add new products to the catalog',
      AdminPermissions.editProducts: 'Modify product information and pricing',
      AdminPermissions.deleteProducts: 'Remove products from the catalog',

      AdminPermissions.viewOrders: 'View customer orders and order details',
      AdminPermissions.processOrders: 'Update order status and process shipments',
      AdminPermissions.cancelOrders: 'Cancel pending or processing orders',
      AdminPermissions.refundOrders: 'Issue refunds for completed orders',

      AdminPermissions.managePermissions: 'Assign and modify admin permissions',
      AdminPermissions.sendNotifications: 'Send push notifications to users',
      // Add more descriptions as needed
    };

    return descriptions[permission] ?? '';
  }

  /// Check if a list of permissions includes a specific permission
  static bool hasPermission(List<String> userPermissions, String permission) {
    return userPermissions.contains(permission);
  }

  /// Check if a list of permissions includes all required permissions
  static bool hasAllPermissions(List<String> userPermissions, List<String> requiredPermissions) {
    return requiredPermissions.every((permission) => userPermissions.contains(permission));
  }

  /// Check if a list of permissions includes any of the required permissions
  static bool hasAnyPermission(List<String> userPermissions, List<String> requiredPermissions) {
    return requiredPermissions.any((permission) => userPermissions.contains(permission));
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