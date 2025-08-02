import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:secondsight/services/auth_provider.dart';
import 'package:secondsight/services/auth_wrapper.dart';
import 'package:secondsight/web/admin/chat/admin_chat_view.dart';
import 'package:secondsight/web/admin/login/admin_login_view.dart';
import 'package:secondsight/web/admin/login/admin_management_view.dart';
import 'package:secondsight/web/admin/product/admin_product.dart';
import 'package:secondsight/web/admin/reports/admin_report.dart';
import 'package:secondsight/web/admin/returnrefund/admin_return.dart';
import 'package:secondsight/web/admin/services/admin_auth_provider.dart';
import 'package:secondsight/web/admin/services/admin_auth_wrapper.dart';
import 'package:secondsight/web/admin/services/permissions_guard.dart';
import 'package:secondsight/web/admin/services/permissions_manager.dart';
import 'package:secondsight/web/admin/widget/sidebar.dart';
import 'firebase_options.dart';
import 'web/admin/customer/admin_customer.dart';
import 'web/admin/dashboard/admin_dashboard.dart';
import 'web/admin/order/admin_order.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AdminAuthProvider()), // ADD THIS
      ],
      child: AdminApp(),
    ),
  );
}

class AdminApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      theme: ThemeData(primaryColor: Color(0xFF7C3AED), fontFamily: 'Inter'),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/' : (context) => AdminAuthWrapper(authenticatedWidget: AdminNavigator()),
        '/admin/login': (context) => AdminLoginView(),
        '/conversations': (context) => AdminAuthWrapper(
          authenticatedWidget: PermissionGuard(
            requiredPermissions: [AdminPermissions.viewSupport],
            child: const AdminChatView(),
            fallback: NoPermissionWidget(feature: 'Customer Support'), // ✅ FIXED HERE
          ),
        ),
      },
    );
  }
}



class AdminNavigator extends StatefulWidget {
  final String? initialPage;

  const AdminNavigator({Key? key, this.initialPage}) : super(key: key);

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
        return OrderManagementPage();
      case 'returns':
        return ReturnManagementPage();
      case 'customers':
        return CustomerManagementPage();
      case 'chat':
        return AdminChatView();
      case 'reports':
        return AdminReportPage();
      case 'admins':
        return AdminManagementPage();
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
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Go to Dashboard'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}