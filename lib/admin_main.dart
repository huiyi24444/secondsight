import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:secondsight/services/auth_provider.dart';
import 'package:secondsight/services/auth_wrapper.dart';
import 'package:secondsight/web/admin/admin_management/admin_setup.dart';
import 'package:secondsight/web/admin/chat/admin_chat_view.dart';
import 'package:secondsight/web/admin/login/admin_login_view.dart';
import 'package:secondsight/web/admin/admin_management/admin_management_view.dart';
import 'package:secondsight/web/admin/product/admin_product.dart';
import 'package:secondsight/web/admin/reports/admin_report.dart';
import 'package:secondsight/web/admin/returnrefund/admin_return.dart';
import 'package:secondsight/web/admin/services/admin_auth_provider.dart';
import 'package:secondsight/web/admin/services/admin_auth_wrapper.dart';
import 'package:secondsight/web/admin/services/admin_nav.dart';
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
      onGenerateRoute: (settings) {
        // Get the current URL from browser
        final uri = Uri.base;
        print('🔍 Browser URL: ${uri.toString()}');
        print('🔍 URI path: ${uri.path}');
        print('🔍 URI query: ${uri.queryParameters}');

        // Check if this is a setup route from the URL
        if (uri.path == '/admin-setup' || uri.fragment.contains('admin-setup')) {
          print('🚀 Setup route detected in URL');
          final token = uri.queryParameters['token'];
          final id = uri.queryParameters['id'];

          if (token != null && id != null) {
            print('✅ Valid setup parameters from URL');
            return MaterialPageRoute(
              builder: (_) => AdminSetupPage(token: token, adminId: id),
            );
          }
        }

        // Original routing logic for settings.name
        final routeUri = Uri.tryParse(settings.name ?? '');

        if (routeUri?.path == '/admin-setup') {
          final token = routeUri?.queryParameters['token'];
          final id = routeUri?.queryParameters['id'];

          if (token != null && id != null) {
            return MaterialPageRoute(
              builder: (_) => AdminSetupPage(token: token, adminId: id),
            );
          }
        }

        // Default routes
        switch (settings.name) {
          case '/admin/login':
            return MaterialPageRoute(builder: (_) => AdminLoginView());
          case '/conversations':
            return MaterialPageRoute(
              builder: (_) => AdminAuthWrapper(
                authenticatedWidget: PermissionGuard(
                  requiredPermissions: [AdminPermissions.viewConversations],
                  child: const AdminChatView(),
                  fallback: NoPermissionWidget(feature: 'Customer Support'),
                ),
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => AdminAuthWrapper(authenticatedWidget: AdminNavigator()),
            );
        }
      },
    );
  }
}