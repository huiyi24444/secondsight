import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../model/admin_log_model.dart';
import '../../../model/admin_model.dart';

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

  List<String> getRolePermissions(String role) {
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

}
