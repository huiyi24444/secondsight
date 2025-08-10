import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondsight/web/admin/services/permissions_guard.dart';
import 'package:secondsight/web/admin/services/permissions_manager.dart';

import '../admin_management/admin_management_view.dart';
import '../chat/admin_chat_view.dart';
import '../customer/admin_customer.dart';
import '../dashboard/admin_dashboard.dart';
import '../order/admin_order.dart';
import '../product/admin_product.dart';
import '../reports/admin_report.dart';
import '../returnrefund/admin_return.dart';
import '../widget/sidebar.dart';
import 'admin_auth_provider.dart';

class AdminNavigator extends StatefulWidget {
  final String? initialPage;
  final Map<String, dynamic>? pageParams;

  const AdminNavigator({Key? key, this.initialPage,  this.pageParams}) : super(key: key);

  @override
  _AdminNavigatorState createState() => _AdminNavigatorState();
}

class _AdminNavigatorState extends State<AdminNavigator> {
  String currentPage = 'dashboard';

  @override
  void initState() {
    super.initState();
    // Set the initial page if provided
    if (widget.initialPage != null) {
      currentPage = widget.initialPage!;
    }
  }

  Widget _getPage() {
    switch (currentPage) {
      case 'dashboard':
        return AdminDashboardPage();
      case 'products':
        return PermissionGuard(
          requiredPermissions: [AdminPermissions.viewProducts],
          child: ProductManagementPage(),
          fallback: _buildNoPermissionPage('Product Management'),
        );
      case 'orders':
        return PermissionGuard(
          requiredPermissions: [AdminPermissions.viewOrders],
          child: OrderManagementPage(
            initialTab: widget.pageParams?['initialTab'], // Use widget.pageParams
          ),
          fallback: _buildNoPermissionPage('Order Management'),
        );
      case 'returns':
        return PermissionGuard(
          requiredPermissions: [AdminPermissions.viewReturns],
          child: ReturnManagementPage(
            initialTab: widget.pageParams?['initialTab'],
          ),
          fallback: _buildNoPermissionPage('Return Management'),
        );
      case 'customers':
        return PermissionGuard(
          requiredPermissions: [AdminPermissions.viewUsers],
          child: CustomerManagementPage(),
          fallback: _buildNoPermissionPage('Customer Management'),
        );
      case 'chat':
        return PermissionGuard(
          requiredPermissions: [AdminPermissions.viewConversations],
          child: AdminChatView(),
          fallback: _buildNoPermissionPage('Customer Support'),
        );
      case 'reports':
        return PermissionGuard(
          requiredPermissions: [AdminPermissions.exportReports],
          child: AdminReportPage(),
          fallback: _buildNoPermissionPage('Generate Reports'),
        );
      case 'admins':
        return PermissionGuard(
          requiredPermissions: [AdminPermissions.viewAdmins],
          child: AdminManagementPage(),
          fallback: _buildNoPermissionPage('Admins Management'),
        );
      default:
        return AdminDashboardPage();
    }
  }

  Widget _buildNoPermissionPage(String pageName) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Access Denied',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You don\'t have permission to access $pageName.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please contact your administrator if you need access.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  currentPage = 'dashboard';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminAuthProvider>(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Sidebar
          AdminSidebar(
            currentPage: currentPage,
            onPageChanged: (String page) {
              setState(() {
                currentPage = page;
              });
            },
            adminPermissions: adminProvider.permissions,
          ),
          // Main Content
          Expanded(child: _getPage()),
        ],
      ),
    );
  }
}
class NoPermissionWidget extends StatelessWidget {
  final String feature;
  final VoidCallback? onBackToDashboard;

  const NoPermissionWidget({
    Key? key,
    required this.feature,
    this.onBackToDashboard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Access Denied',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You don\'t have permission to access $feature.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please contact your administrator if you need access.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (onBackToDashboard != null) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onBackToDashboard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Go to Dashboard',style: TextStyle(color: Colors.white),),

              ),
            ],
          ],
        ),
      ),
    );
  }
}