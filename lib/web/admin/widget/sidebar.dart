import 'package:flutter/material.dart';

class AdminSidebar extends StatelessWidget {
  final String currentPage;
  final Function(String) onPageChanged;

  const AdminSidebar({
    Key? key,
    required this.currentPage,
    required this.onPageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: const Color(0xFF7C3AED),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shopping_bag, color: Color(0xFF7C3AED)),
                ),
                const SizedBox(width: 10),
                const Text(
                  'SecondSight',
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
          _buildMenuItem(
            Icons.chat,
            'Chat Support',
            'chat',
            currentPage == 'chat',
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String page, bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        onTap: () {
          onPageChanged(page);
        },
      ),
    );
  }
}