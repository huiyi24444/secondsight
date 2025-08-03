// File: lib/mixins/activity_logger_mixin.dart
import '../../../model/admin_log_model.dart';
import 'admin_session_service.dart';

mixin ActivityLoggerMixin {
  // Get current admin info
  Map<String, dynamic> get _adminInfo => AdminSessionService.instance.logInfo;

  // Log CRUD operations
  Future<void> logCrud({
    required String operation,
    required String targetType,
    required String targetId,
    String? targetName,
    Map<String, dynamic>? changes,
    Map<String, dynamic>? previousData,
    bool isSuccessful = true,
    String? errorMessage,
  }) async {
    await AdminActivityLogger.logCrudOperation(
      adminId: _adminInfo['adminId'],
      adminEmail: _adminInfo['adminEmail'],
      adminName: _adminInfo['adminName'],
      adminRole: _adminInfo['adminRole'],
      operation: operation,
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
      changes: changes,
      previousData: previousData,
      isSuccessful: isSuccessful,
      errorMessage: errorMessage,
    );
  }

  // Log permission changes
  Future<void> logPermission({
    required String targetAdminId,
    required String targetAdminName,
    required Map<String, dynamic> changes,
  }) async {
    await AdminActivityLogger.logPermissionChange(
      adminId: _adminInfo['adminId'],
      adminEmail: _adminInfo['adminEmail'],
      adminName: _adminInfo['adminName'],
      adminRole: _adminInfo['adminRole'],
      targetAdminId: targetAdminId,
      targetAdminName: targetAdminName,
      changes: changes,
    );
  }

  // Log bulk operations
  Future<void> logBulk({
    required String operation,
    required String targetType,
    required int count,
    Map<String, dynamic>? details,
  }) async {
    await AdminActivityLogger.logBulkOperation(
      adminId: _adminInfo['adminId'],
      adminEmail: _adminInfo['adminEmail'],
      adminName: _adminInfo['adminName'],
      adminRole: _adminInfo['adminRole'],
      operation: operation,
      targetType: targetType,
      affectedCount: count,
      details: details,
    );
  }
}
