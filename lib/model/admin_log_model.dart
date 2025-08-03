// admin_activity_log_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin Activity Log Model for top-level collection
class AdminActivityLog {
  final String id;

  // Admin Information (denormalized for fast queries)
  final String adminId;
  final String adminEmail;
  final String adminName;
  final String adminRole;

  // Action Details
  final String action; // e.g., 'create_product', 'delete_user', 'login'
  final String actionType; // 'auth', 'crud', 'settings', 'permission'
  final String targetType; // 'product', 'user', 'order', 'admin', 'settings'
  final String? targetId; // ID of affected resource
  final String? targetName; // Name/title for better readability

  // Metadata
  final DateTime timestamp;
  final String? ipAddress;
  final String? userAgent;
  final String? deviceInfo;
  final Map<String, dynamic>? details; // Additional context

  // Status
  final bool isSuccessful;
  final String? errorMessage;
  final String? errorCode;

  AdminActivityLog({
    required this.id,
    required this.adminId,
    required this.adminEmail,
    required this.adminName,
    required this.adminRole,
    required this.action,
    required this.actionType,
    required this.targetType,
    this.targetId,
    this.targetName,
    required this.timestamp,
    this.ipAddress,
    this.userAgent,
    this.deviceInfo,
    this.details,
    this.isSuccessful = true,
    this.errorMessage,
    this.errorCode,
  });

  /// Create from Firestore document
  factory AdminActivityLog.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AdminActivityLog(
      id: doc.id,
      adminId: data['adminId'] ?? '',
      adminEmail: data['adminEmail'] ?? '',
      adminName: data['adminName'] ?? '',
      adminRole: data['adminRole'] ?? '',
      action: data['action'] ?? '',
      actionType: data['actionType'] ?? 'other',
      targetType: data['targetType'] ?? 'unknown',
      targetId: data['targetId'],
      targetName: data['targetName'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      ipAddress: data['ipAddress'],
      userAgent: data['userAgent'],
      deviceInfo: data['deviceInfo'],
      details: data['details'] != null
          ? Map<String, dynamic>.from(data['details'])
          : null,
      isSuccessful: data['isSuccessful'] ?? true,
      errorMessage: data['errorMessage'],
      errorCode: data['errorCode'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'adminId': adminId,
      'adminEmail': adminEmail,
      'adminName': adminName,
      'adminRole': adminRole,
      'action': action,
      'actionType': actionType,
      'targetType': targetType,
      if (targetId != null) 'targetId': targetId,
      if (targetName != null) 'targetName': targetName,
      'timestamp': Timestamp.fromDate(timestamp),
      if (ipAddress != null) 'ipAddress': ipAddress,
      if (userAgent != null) 'userAgent': userAgent,
      if (deviceInfo != null) 'deviceInfo': deviceInfo,
      if (details != null && details!.isNotEmpty) 'details': details,
      'isSuccessful': isSuccessful,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (errorCode != null) 'errorCode': errorCode,
    };
  }

  /// Get human-readable action description
  String get actionDescription {
    switch (actionType) {
      case 'auth':
        return _getAuthDescription();
      case 'crud':
        return _getCrudDescription();
      case 'settings':
        return _getSettingsDescription();
      case 'permission':
        return _getPermissionDescription();
      default:
        return action.replaceAll('_', ' ').capitalize();
    }
  }

  String _getAuthDescription() {
    switch (action) {
      case 'login_success':
        return 'Logged in successfully';
      case 'login_failed':
        return 'Failed login attempt';
      case 'logout':
        return 'Logged out';
      case 'password_changed':
        return 'Changed password';
      case 'password_reset_requested':
        return 'Requested password reset';
      case 'session_expired':
        return 'Session expired';
      default:
        return action.replaceAll('_', ' ').capitalize();
    }
  }

  String _getCrudDescription() {
    final operation = action.split('_').first;
    final target = targetName != null ? '"$targetName"' : '#$targetId';

    switch (operation) {
      case 'create':
        return 'Created $targetType $target';
      case 'update':
        return 'Updated $targetType $target';
      case 'delete':
        return 'Deleted $targetType $target';
      case 'view':
        return 'Viewed $targetType $target';
      case 'export':
        return 'Exported $targetType data';
      case 'import':
        return 'Imported $targetType data';
      default:
        return '$operation $targetType $target';
    }
  }

  String _getSettingsDescription() {
    return 'Modified ${targetType.replaceAll('_', ' ')} settings';
  }

  String _getPermissionDescription() {
    final target = targetName ?? targetId ?? 'unknown';
    return 'Changed permissions for $target';
  }

  /// Get severity level for monitoring
  String get severity {
    // Failed auth attempts
    if (actionType == 'auth' && !isSuccessful) return 'warning';

    // Multiple failed attempts
    if (action == 'multiple_failed_logins') return 'critical';

    // Deletions
    if (action.contains('delete')) return 'high';

    // Permission changes
    if (actionType == 'permission') return 'high';

    // Bulk operations
    if (action.contains('bulk_')) return 'medium';

    // Exports
    if (action.contains('export')) return 'medium';

    // Normal operations
    return 'low';
  }

  /// Check if this is a security-relevant event
  bool get isSecurityEvent {
    return actionType == 'auth' ||
        actionType == 'permission' ||
        !isSuccessful ||
        action.contains('delete') ||
        action.contains('export');
  }
}

/// Service class for logging admin activities
class AdminActivityLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'admin_activity_logs';

  /// Log an activity
  static Future<void> log({
    required String adminId,
    required String adminEmail,
    required String adminName,
    required String adminRole,
    required String action,
    required String actionType,
    required String targetType,
    String? targetId,
    String? targetName,
    String? ipAddress,
    String? userAgent,
    String? deviceInfo,
    Map<String, dynamic>? details,
    bool isSuccessful = true,
    String? errorMessage,
    String? errorCode,
  }) async {
    try {
      final log = AdminActivityLog(
        id: '', // Auto-generated
        adminId: adminId,
        adminEmail: adminEmail,
        adminName: adminName,
        adminRole: adminRole,
        action: action,
        actionType: actionType,
        targetType: targetType,
        targetId: targetId,
        targetName: targetName,
        timestamp: DateTime.now(),
        ipAddress: ipAddress,
        userAgent: userAgent,
        deviceInfo: deviceInfo,
        details: details,
        isSuccessful: isSuccessful,
        errorMessage: errorMessage,
        errorCode: errorCode,
      );

      await _firestore.collection(_collection).add(log.toMap());
    } catch (e) {
      print('Error logging activity: $e');
      // Don't throw - logging shouldn't break the app
    }
  }

  /// Convenience methods for common actions

  static Future<void> logLogin({
    required String adminId,
    required String adminEmail,
    required String adminName,
    required String adminRole,
    String? ipAddress,
    String? userAgent,
    String? deviceInfo,
    bool isSuccessful = true,
    String? errorMessage,
  }) async {
    await log(
      adminId: adminId,
      adminEmail: adminEmail,
      adminName: adminName,
      adminRole: adminRole,
      action: isSuccessful ? 'login_success' : 'login_failed',
      actionType: 'auth',
      targetType: 'session',
      ipAddress: ipAddress,
      userAgent: userAgent,
      deviceInfo: deviceInfo,
      details: {
        'loginMethod': 'email',
        'timestamp': DateTime.now().toIso8601String(),
      },
      isSuccessful: isSuccessful,
      errorMessage: errorMessage,
    );
  }

  static Future<void> logCrudOperation({
    required String adminId,
    required String adminEmail,
    required String adminName,
    required String adminRole,
    required String operation, // 'create', 'update', 'delete', 'view'
    required String targetType, // 'product', 'user', 'order', etc.
    required String targetId,
    String? targetName,
    Map<String, dynamic>? changes,
    Map<String, dynamic>? previousData,
    bool isSuccessful = true,
    String? errorMessage,
  }) async {
    await log(
      adminId: adminId,
      adminEmail: adminEmail,
      adminName: adminName,
      adminRole: adminRole,
      action: '${operation}_$targetType',
      actionType: 'crud',
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
      details: {
        'operation': operation,
        if (changes != null) 'changes': changes,
        if (previousData != null) 'previousData': previousData,
        'timestamp': DateTime.now().toIso8601String(),
      },
      isSuccessful: isSuccessful,
      errorMessage: errorMessage,
    );
  }

  static Future<void> logPermissionChange({
    required String adminId,
    required String adminEmail,
    required String adminName,
    required String adminRole,
    required String targetAdminId,
    required String targetAdminName,
    required Map<String, dynamic> changes,
  }) async {
    await log(
      adminId: adminId,
      adminEmail: adminEmail,
      adminName: adminName,
      adminRole: adminRole,
      action: 'modify_permissions',
      actionType: 'permission',
      targetType: 'admin',
      targetId: targetAdminId,
      targetName: targetAdminName,
      details: {
        'changes': changes,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static Future<void> logBulkOperation({
    required String adminId,
    required String adminEmail,
    required String adminName,
    required String adminRole,
    required String operation,
    required String targetType,
    required int affectedCount,
    Map<String, dynamic>? details,
  }) async {
    await log(
      adminId: adminId,
      adminEmail: adminEmail,
      adminName: adminName,
      adminRole: adminRole,
      action: 'bulk_${operation}_$targetType',
      actionType: 'crud',
      targetType: targetType,
      details: {
        'affectedCount': affectedCount,
        'operation': operation,
        if (details != null) ...details,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Query methods

  /// Get logs for a specific admin
  static Stream<List<AdminActivityLog>> getAdminLogs(
      String adminId, {
        int limit = 100,
      }) {
    return _firestore
        .collection(_collection)
        .where('adminId', isEqualTo: adminId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => AdminActivityLog.fromDocument(doc))
        .toList());
  }

  /// Get all logs with optional filters
  static Stream<List<AdminActivityLog>> getAllLogs({
    String? actionType,
    String? targetType,
    bool? isSuccessful,
    int limit = 100,
  }) {
    Query query = _firestore.collection(_collection);

    if (actionType != null) {
      query = query.where('actionType', isEqualTo: actionType);
    }
    if (targetType != null) {
      query = query.where('targetType', isEqualTo: targetType);
    }
    if (isSuccessful != null) {
      query = query.where('isSuccessful', isEqualTo: isSuccessful);
    }

    return query
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => AdminActivityLog.fromDocument(doc))
        .toList());
  }

  /// Get security events
  static Stream<List<AdminActivityLog>> getSecurityEvents({
    int limit = 50,
  }) {
    return _firestore
        .collection(_collection)
        .where('actionType', whereIn: ['auth', 'permission'])
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => AdminActivityLog.fromDocument(doc))
        .toList());
  }

  /// Get failed operations
  static Stream<List<AdminActivityLog>> getFailedOperations({
    int limit = 50,
  }) {
    return _firestore
        .collection(_collection)
        .where('isSuccessful', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => AdminActivityLog.fromDocument(doc))
        .toList());
  }

  /// Get logs by date range
  static Future<List<AdminActivityLog>> getLogsByDateRange({
    String? adminId,
    required DateTime startDate,
    required DateTime endDate,
    String? actionType,
  }) async {
    Query query = _firestore.collection(_collection);

    if (adminId != null) {
      query = query.where('adminId', isEqualTo: adminId);
    }
    if (actionType != null) {
      query = query.where('actionType', isEqualTo: actionType);
    }

    final snapshot = await query
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => AdminActivityLog.fromDocument(doc))
        .toList();
  }

  /// Count logs by action type for analytics
  static Future<Map<String, int>> getActionTypeCounts({
    String? adminId,
    DateTime? startDate,
  }) async {
    Query query = _firestore.collection(_collection);

    if (adminId != null) {
      query = query.where('adminId', isEqualTo: adminId);
    }
    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    final snapshot = await query.get();
    final counts = <String, int>{};

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final actionType = data['actionType'] as String;
      counts[actionType] = (counts[actionType] ?? 0) + 1;
    }

    return counts;
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

/*
FIREBASE STRUCTURE:
==================

/admin_activity_logs
  /{auto-generated-id}
    - adminId: "admin_123"
    - adminEmail: "john@example.com"
    - adminName: "John Doe"
    - adminRole: "super_admin"
    - action: "update_product"
    - actionType: "crud"
    - targetType: "product"
    - targetId: "prod_456"
    - targetName: "iPhone 15 Pro"
    - timestamp: Timestamp(2024-01-15 10:30:00)
    - ipAddress: "192.168.1.100"
    - userAgent: "Mozilla/5.0..."
    - deviceInfo: "Windows 10, Chrome 120"
    - details: {
        "operation": "update",
        "changes": {
          "price": { "old": 999, "new": 899 },
          "stock": { "old": 50, "new": 75 }
        },
        "timestamp": "2024-01-15T10:30:00Z"
      }
    - isSuccessful: true

FIRESTORE INDEXES NEEDED:
========================
1. adminId + timestamp (DESC)
2. actionType + timestamp (DESC)
3. targetType + timestamp (DESC)
4. isSuccessful + timestamp (DESC)
5. timestamp (DESC)

USAGE EXAMPLES:
==============
*/

