import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:secondsight/web/admin/chat/admin_chat_view.dart';
import 'package:secondsight/web/admin/product/admin_product.dart';
import 'package:secondsight/web/admin/returnrefund/admin_return.dart';
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
          Container(
            width: 250,
            color: Color(0xFF7C3AED),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shopping_bag, color: Color(0xFF7C3AED)),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Logo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildMenuItem(
                  Icons.dashboard,
                  'Dashboard',
                  'dashboard',
                  currentPage == 'dashboard',
                ),
                _buildMenuItem(
                  Icons.shopping_cart,
                  'Product Management',
                  'products',
                  currentPage == 'products',
                ),
                _buildMenuItem(
                  Icons.list_alt,
                  'Order Management',
                  'orders',
                  currentPage == 'orders',
                ),
                _buildMenuItem(
                  Icons.assignment_return,
                  'Return Management',
                  'returns',
                  currentPage == 'returns',
                ),
                _buildMenuItem(
                  Icons.people,
                  'Customer Management',
                  'customers',
                  currentPage == 'customers',
                ),
                _buildMenuItem(
                  Icons.report,
                  'Reports',
                  'reports',
                  currentPage == 'reports',
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: _getPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String page, bool isActive) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        onTap: () {
          setState(() {
            currentPage = page;
          });
        },
      ),
    );
  }
}