import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:secondsight/web/admin/chat/admin_chat_view.dart';
import 'package:secondsight/web/admin/product/admin_product.dart';
import 'package:secondsight/web/admin/returnrefund/admin_return.dart';
import 'package:secondsight/web/admin/widget/sidebar.dart';
import 'firebase_options.dart';
import 'web/admin/customer/admin_customer.dart';
import 'web/admin/dashboard/admin_dashboard.dart';
import 'web/admin/order/admin_order.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(AdminApp());
}

class AdminApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      theme: ThemeData(
        primaryColor: Color(0xFF7C3AED),
        fontFamily: 'Inter',
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => AdminNavigator(),
        '/conversations': (context) => const AdminChatView(),
      },
    );
  }
}

class AdminNavigator extends StatefulWidget {
  @override
  _AdminNavigatorState createState() => _AdminNavigatorState();
}

class _AdminNavigatorState extends State<AdminNavigator> {
  String currentPage = 'dashboard';

  Widget _getPage() {
    switch (currentPage) {
      case 'dashboard':
        return AdminDashboardPage();
      case 'products':
        return ProductManagementPage();
      case 'orders':
        return OrderManagementPage();
      case 'returns':
        return ReturnManagementPage();
      case 'customers':
        return CustomerManagementPage();
      default:
        return AdminDashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          ),
          // Main Content
          Expanded(
            child: _getPage(),
          ),
        ],
      ),
    );
  }
}