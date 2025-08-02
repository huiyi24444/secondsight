// permission_guard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondsight/web/admin/services/permissions_manager.dart';
import '../services/admin_auth_provider.dart';

/// Widget that shows or hides its child based on admin permissions
class PermissionGuard extends StatelessWidget {
  final Widget child;
  final List<String> requiredPermissions;
  final bool requireAll;
  final Widget? fallback;
  final bool showMessage;

  const PermissionGuard({
    Key? key,
    required this.child,
    required this.requiredPermissions,
    this.requireAll = false,
    this.fallback,
    this.showMessage = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminAuthProvider>(context);

    final hasPermission = requireAll
        ? adminProvider.hasAllPermissions(requiredPermissions)
        : adminProvider.hasAnyPermission(requiredPermissions);

    if (hasPermission) {
      return child;
    }

    if (fallback != null) {
      return fallback!;
    }

    if (showMessage) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'Permission Required',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You need the following permissions:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            ...requiredPermissions.map((permission) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• ${PermissionHelper.getPermissionName(permission)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            )),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Button that is enabled/disabled based on permissions
class PermissionButton extends StatelessWidget {
  final Widget child;
  final List<String> requiredPermissions;
  final bool requireAll;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final String? disabledTooltip;

  const PermissionButton({
    Key? key,
    required this.child,
    required this.requiredPermissions,
    required this.onPressed,
    this.requireAll = false,
    this.style,
    this.disabledTooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminAuthProvider>(context);

    final hasPermission = requireAll
        ? adminProvider.hasAllPermissions(requiredPermissions)
        : adminProvider.hasAnyPermission(requiredPermissions);

    final button = ElevatedButton(
      onPressed: hasPermission ? onPressed : null,
      style: style,
      child: child,
    );

    if (!hasPermission && disabledTooltip != null) {
      return Tooltip(
        message: disabledTooltip!,
        child: button,
      );
    }

    return button;
  }
}

/// IconButton that is enabled/disabled based on permissions
class PermissionIconButton extends StatelessWidget {
  final Icon icon;
  final List<String> requiredPermissions;
  final bool requireAll;
  final VoidCallback? onPressed;
  final String? tooltip;
  final String? disabledTooltip;

  const PermissionIconButton({
    Key? key,
    required this.icon,
    required this.requiredPermissions,
    required this.onPressed,
    this.requireAll = false,
    this.tooltip,
    this.disabledTooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminAuthProvider>(context);

    final hasPermission = requireAll
        ? adminProvider.hasAllPermissions(requiredPermissions)
        : adminProvider.hasAnyPermission(requiredPermissions);

    return Tooltip(
      message: hasPermission
          ? (tooltip ?? '')
          : (disabledTooltip ?? 'Permission required'),
      child: IconButton(
        icon: icon,
        onPressed: hasPermission ? onPressed : null,
      ),
    );
  }
}

/// Route guard that checks permissions before allowing navigation
class PermissionRoute extends StatelessWidget {
  final Widget child;
  final List<String> requiredPermissions;
  final bool requireAll;
  final String? redirectRoute;

  const PermissionRoute({
    Key? key,
    required this.child,
    required this.requiredPermissions,
    this.requireAll = false,
    this.redirectRoute,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminAuthProvider>(context);

    final hasPermission = requireAll
        ? adminProvider.hasAllPermissions(requiredPermissions)
        : adminProvider.hasAnyPermission(requiredPermissions);

    if (!hasPermission) {
      // Schedule navigation after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (redirectRoute != null) {
          Navigator.of(context).pushReplacementNamed(redirectRoute!);
        } else {
          Navigator.of(context).pushReplacementNamed('/admin');
        }
      });

      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return child;
  }
}

/// Example usage widget
class PermissionExampleScreen extends StatelessWidget {
  const PermissionExampleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Examples'),
        actions: [
          // Only show if admin has delete permission
          PermissionIconButton(
            icon: const Icon(Icons.delete),
            requiredPermissions: [AdminPermissions.deleteProducts],
            onPressed: () {
              // Delete action
            },
            tooltip: 'Delete Product',
            disabledTooltip: 'You need delete permission',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show different content based on permissions
            PermissionGuard(
              requiredPermissions: [AdminPermissions.viewAnalytics],
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.analytics),
                  title: const Text('Analytics Dashboard'),
                  subtitle: const Text('View sales and user analytics'),
                  onTap: () {
                    // Navigate to analytics
                  },
                ),
              ),
              fallback: const Card(
                child: ListTile(
                  leading: Icon(Icons.lock),
                  title: Text('Analytics Dashboard'),
                  subtitle: Text('Permission required to view analytics'),
                  enabled: false,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Button with permission check
            PermissionButton(
              requiredPermissions: [AdminPermissions.createProducts],
              onPressed: () {
                // Create product action
              },
              disabledTooltip: 'You need create product permission',
              child: const Text('Add New Product'),
            ),

            const SizedBox(height: 16),

            // Multiple permissions (require all)
            PermissionGuard(
              requiredPermissions: [
                AdminPermissions.viewFinancials,
                AdminPermissions.exportReports,
              ],
              requireAll: true,
              showMessage: true,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Financial Reports'),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Export Financial Report'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}