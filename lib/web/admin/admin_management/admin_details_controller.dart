import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../model/admin_log_model.dart';
import '../../../model/admin_model.dart';
import '../services/permissions_manager.dart';

class AdminDetailsController extends ChangeNotifier {
  AdminModel? _admin;
  bool _isLoading = false;
  String? _error;

  List<AdminActivityLog> _activityLogs = [];
  bool _isLoadingLogs = true;
  String _selectedLogFilter = 'All';

  AdminModel? get admin => _admin;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _admin != null;
  bool get isLoadingLogs => _isLoadingLogs;

  String get selectedLogFilter => _selectedLogFilter;

  List<AdminActivityLog> get activityLogs => _activityLogs;

  set selectedLogFilter(String filter) {
    _selectedLogFilter = filter;
    notifyListeners();
  }

  List<AdminActivityLog> get filteredLogs {
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

  Future<void> loadActivityLogs(String adminId) async {
    _isLoadingLogs = true;
    notifyListeners();

    try {
      final logsSnapshot = await FirebaseFirestore.instance
          .collection('admin_activity_logs')
          .where('adminId', isEqualTo: adminId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      print('Retrieved ${logsSnapshot.docs.length} activity logs for adminId: $adminId');

      for (var doc in logsSnapshot.docs) {
        print('Log Document ID: ${doc.id}, Data: ${doc.data()}');
      }

      _activityLogs = logsSnapshot.docs
          .map((doc) => AdminActivityLog.fromDocument(doc))
          .toList();
    } catch (e) {
      print('Error loading activity logs: $e');
    }

    _isLoadingLogs = false;
    notifyListeners();
  }

  Future<void> fetchAdminById(String adminId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(adminId)
          .get();

      if (doc.exists && doc.data() != null) {
        _admin = AdminModel.fromDocument(doc);

        // Update the admin's permissions array to match the role permissions
        await syncAdminPermissionsWithRole(adminId);
      } else {
        _error = 'Admin not found';
      }
    } catch (e) {
      _error = 'Error fetching admin: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sync the admin document's permissions array with their role permissions
  Future<void> syncAdminPermissionsWithRole(String adminId) async {
    if (_admin == null) return;

    try {
      final rolePermissions = PermissionHelper.getPermissionsForRole(_admin!.role);

      // Update the admin document with the correct permissions
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(adminId)
          .update({
        'permissions': rolePermissions,
      });

      debugPrint('Synced permissions for admin $adminId with role ${_admin!.role}');
    } catch (e) {
      debugPrint('Error syncing permissions: $e');
    }
  }

  // Get permissions from role definition
  List<String> getRolePermissions() {
    if (_admin == null) return [];
    return PermissionHelper.getPermissionsForRole(_admin!.role);
  }

  // Get permissions grouped by PermissionGroups
  Map<String, List<String>> getGroupedPermissions() {
    if (_admin == null) return {};

    final rolePermissions = getRolePermissions();
    final groupedPermissions = <String, List<String>>{};

    PermissionGroups.groups.forEach((key, group) {
      final groupPermissions = group.permissions
          .where((permission) => rolePermissions.contains(permission))
          .toList();

      if (groupPermissions.isNotEmpty) {
        groupedPermissions[key] = groupPermissions;
      }
    });

    return groupedPermissions;
  }

  DateTime? get lastLoginDate {
    if (_admin?.lastLogin != null) {
      return _admin!.lastLogin;
    }

    // Fallback: Find most recent login from activity logs
    final loginLogs = _activityLogs
        .where((log) => log.action.toLowerCase().contains('login'))
        .toList();

    if (loginLogs.isNotEmpty) {
      loginLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return loginLogs.first.timestamp;
    }

    return null;
  }


  int get totalLoginsThisMonth {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return _activityLogs
        .where((log) =>
    log.action.toLowerCase().contains('login') &&
        log.timestamp.isAfter(startOfMonth))
        .length;
  }

// Failed login tracking
  int get failedLoginAttempts {
    final now = DateTime.now();
    final last7Days = now.subtract(const Duration(days: 7));

    return _activityLogs
        .where((log) =>
    (log.action.toLowerCase().contains('failed') &&
        log.action.toLowerCase().contains('login')) ||
        log.timestamp.isAfter(last7Days))
        .length;
  }

  int get sessionsToday {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    // Count login actions for today
    return _activityLogs
        .where((log) =>
    log.action.toLowerCase().contains('login') &&
        log.timestamp.isAfter(startOfDay))
        .length;
  }

  // Additional activity summary methods
  int get totalActivitiesToday {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return _activityLogs
        .where((log) => log.timestamp.isAfter(startOfDay))
        .length;
  }

  int get totalActivitiesThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    return _activityLogs
        .where((log) => log.timestamp.isAfter(startOfWeekMidnight))
        .length;
  }

  String get mostCommonActionThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    final weeklyLogs = _activityLogs
        .where((log) => log.timestamp.isAfter(startOfWeekMidnight))
        .toList();

    if (weeklyLogs.isEmpty) return 'No activity';

    // Group by action type and count
    final actionCounts = <String, int>{};
    for (final log in weeklyLogs) {
      final actionType = _getActionCategory(log.action);
      actionCounts[actionType] = (actionCounts[actionType] ?? 0) + 1;
    }

    if (actionCounts.isEmpty) return 'No activity';

    // Find most common action
    var maxCount = 0;
    var mostCommon = 'Various';
    actionCounts.forEach((action, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommon = action;
      }
    });

    return mostCommon;
  }

  String _getActionCategory(String action) {
    final lowerAction = action.toLowerCase();
    if (lowerAction.contains('login') || lowerAction.contains('logout')) {
      return 'Authentication';
    } else if (lowerAction.contains('create') || lowerAction.contains('add')) {
      return 'Create';
    } else if (lowerAction.contains('update') || lowerAction.contains('edit') || lowerAction.contains('modify')) {
      return 'Update';
    } else if (lowerAction.contains('delete') || lowerAction.contains('remove')) {
      return 'Delete';
    } else if (lowerAction.contains('view') || lowerAction.contains('read')) {
      return 'View';
    } else if (lowerAction.contains('settings') || lowerAction.contains('config')) {
      return 'Settings';
    } else {
      return 'Other';
    }
  }

  Duration? get averageSessionDuration {
    // This would require login/logout pairs to calculate
    // For now, return null as we'd need more sophisticated tracking
    return null;
  }

  IconData getLogIcon(String action) {
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

  Color getLogColor(String action) {
    if (action.contains('login') || action.contains('logout')) return Colors.blue;
    if (action.contains('create')) return Colors.green;
    if (action.contains('update')) return Colors.orange;
    if (action.contains('delete')) return Colors.red;
    if (action.contains('settings') || action.contains('permission')) return Colors.purple;
    return Colors.grey;
  }

  String formatLogDetails(Map<String, dynamic> details) {
    final List<String> parts = [];
    details.forEach((key, value) {
      if (value != null) {
        parts.add('$key: $value');
      }
    });
    return parts.join(', ');
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

  Color getRoleColor(String role) {
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

  // Helper method to format DateTime
  String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Never';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  // Helper method to format numbers for display
  String formatCount(int count) {
    if (count == 0) return '0';
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}