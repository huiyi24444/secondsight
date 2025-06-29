import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int totalRevenue = 0;
  int totalCustomers = 0;
  int completedOrders = 0;
  int activeOrders = 0;
  int allOrders = 0;
  int pendingOrders = 0;

  List<Map<String, dynamic>> recentOrders = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      // Get total revenue
      final ordersSnapshot = await _firestore.collection('Order').get();
      double revenue = 0;
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        if (data['orderStatus'] == 'completed') {
          revenue += (data['total'] ?? 0).toDouble();
        }
      }

      // Get customer count
      final customersSnapshot = await _firestore.collection('Customer').get();

      // Get order statistics
      int active = 0;
      int pending = 0;
      int completed = 0;

      for (var doc in ordersSnapshot.docs) {
        final status = doc.data()['orderStatus'];
        if (status == 'completed') completed++;
        else if (status == 'pending') pending++;
        else if (status == 'processing' || status == 'shipped') active++;
      }

      // Get recent orders
      final recentOrdersSnapshot = await _firestore
          .collection('Order')
          .orderBy('date', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> orders = [];
      for (var doc in recentOrdersSnapshot.docs) {
        final data = doc.data();
        orders.add({
          'orderId': doc.id,
          'date': data['date'],
          'status': data['orderStatus'],
          'total': data['total'],
        });
      }

      setState(() {
        totalRevenue = revenue.toInt();
        totalCustomers = customersSnapshot.docs.length;
        completedOrders = completed;
        activeOrders = active;
        pendingOrders = pending;
        allOrders = ordersSnapshot.docs.length;
        recentOrders = orders;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
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
                // Logo Section
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
                // Menu Items
                _buildMenuItem(Icons.dashboard, 'Dashboard', true),
                _buildMenuItem(Icons.shopping_cart, 'Product Management', false),
                _buildMenuItem(Icons.list_alt, 'Order Management', false),
                _buildMenuItem(Icons.people, 'Customer Management', false),
                _buildMenuItem(Icons.report, 'Reports', false),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 60,
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'All Shop',
                          style: TextStyle(color: Colors.orange[800]),
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.notifications_outlined),
                      SizedBox(width: 10),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[300],
                        child: Icon(Icons.person, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Stats Row
                        Row(
                          children: [
                            _buildStatCard(
                              'Total Revenue Cost',
                              '\$$totalRevenue',
                              '20%',
                              Icons.attach_money,
                              Colors.purple,
                            ),
                            SizedBox(width: 20),
                            _buildStatCard(
                              'Customers',
                              totalCustomers.toString(),
                              '30',
                              Icons.people,
                              Colors.blue,
                            ),
                            SizedBox(width: 20),
                            _buildStatCard(
                              'Orders',
                              allOrders.toString(),
                              '1,250',
                              Icons.shopping_cart,
                              Colors.orange,
                            ),
                            SizedBox(width: 20),
                            _buildStatCard(
                              'Active',
                              activeOrders.toString(),
                              '1,180',
                              Icons.check_circle,
                              Colors.green,
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            _buildStatCard(
                              'All Orders',
                              allOrders.toString(),
                              '0',
                              Icons.list_alt,
                              Colors.blue,
                            ),
                            SizedBox(width: 20),
                            _buildStatCard(
                              'Pending',
                              pendingOrders.toString(),
                              '0',
                              Icons.pending,
                              Colors.orange,
                            ),
                            SizedBox(width: 20),
                            _buildStatCard(
                              'Completed',
                              completedOrders.toString(),
                              '0',
                              Icons.check_circle,
                              Colors.green,
                            ),
                            SizedBox(width: 20),
                            Expanded(child: Container()),
                          ],
                        ),
                        SizedBox(height: 30),
                        // Chart and Recent Orders
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Chart Section
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 400,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Summary',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        DropdownButton<String>(
                                          value: 'Sales',
                                          items: ['Sales', 'Revenue', 'Orders']
                                              .map((e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ))
                                              .toList(),
                                          onChanged: (value) {},
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 20),
                                    Expanded(
                                      child: _buildChart(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 20),
                            // Recent Orders Section
                            Expanded(
                              child: Container(
                                height: 400,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Recent Orders',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Icon(Icons.more_vert),
                                      ],
                                    ),
                                    SizedBox(height: 20),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: recentOrders.length,
                                        itemBuilder: (context, index) {
                                          final order = recentOrders[index];
                                          return _buildOrderItem(order);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, bool isActive) {
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
          // Navigation logic here
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String change, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '+$change',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    return CustomPaint(
      size: Size.infinite,
      painter: ChartPainter(),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> order) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.image, color: Colors.grey[600]),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vintage Denim Jacket',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '#${order['orderId']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                order['date'] != null
                    ? '${DateTime.fromMillisecondsSinceEpoch(order['date']).day} ${_getMonth(DateTime.fromMillisecondsSinceEpoch(order['date']).month)} ${DateTime.fromMillisecondsSinceEpoch(order['date']).year}'
                    : 'No date',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 2),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(order['status']),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  order['status'] ?? 'pending',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getMonth(int month) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFF7C3AED)
      ..strokeWidth = 2;

    final data = [0.3, 0.5, 0.8, 0.4, 0.6, 0.9, 0.7];
    final spacing = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * spacing;
      final height = data[i] * size.height * 0.7;
      final y = size.height - height;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 15, y, 30, height),
          Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}