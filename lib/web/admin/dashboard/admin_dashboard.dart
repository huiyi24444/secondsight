import 'package:flutter/material.dart';
import '../../../model/order_model.dart';
import 'admin_dashboard_controller.dart';
import 'chart_painter.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _controller = AdminDashboardController();
  late DashboardStats data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final result = await _controller.fetchDashboardStats();
    setState(() {
      data = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildStats(),
                        const SizedBox(height: 30),
                        _buildSummaryAndOrders(),
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

  Widget _buildTopBar() => Container(
    height: 60,
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        const Text('Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(5)),
          child: Text('All Shop', style: TextStyle(color: Colors.orange[800])),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.notifications_outlined),
        const SizedBox(width: 10),
        CircleAvatar(radius: 20, backgroundColor: Colors.grey[300], child: const Icon(Icons.person, color: Colors.grey)),
      ],
    ),
  );

  Widget _buildStats() => Column(
    children: [
      Row(
        children: [
          _buildStatCard('Total Revenue', '\$${data.totalRevenue}', '20%', Icons.attach_money, Colors.purple),
          const SizedBox(width: 20),
          _buildStatCard('Customers', '${data.totalCustomers}', '30', Icons.people, Colors.blue),
          const SizedBox(width: 20),
          _buildStatCard('Orders', '${data.allOrders}', '1250', Icons.shopping_cart, Colors.orange),
          const SizedBox(width: 20),
          _buildStatCard('Active', '${data.activeOrders}', '1180', Icons.check_circle, Colors.green),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          _buildStatCard('All Orders', '${data.allOrders}', '0', Icons.list_alt, Colors.blue),
          const SizedBox(width: 20),
          _buildStatCard('Pending', '${data.pendingOrders}', '0', Icons.pending, Colors.orange),
          const SizedBox(width: 20),
          _buildStatCard('Completed', '${data.completedOrders}', '0', Icons.check_circle, Colors.green),
          const SizedBox(width: 20),
          const Expanded(child: SizedBox()),
        ],
      )
    ],
  );

  Widget _buildStatCard(String title, String value, String change, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(4)),
                child: Text('+$change', style: TextStyle(color: Colors.green[700], fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );

  Widget _buildSummaryAndOrders() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 2,
        child: Container(
          height: 400,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Summar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: 'Sales',
                    items: ['Sales', 'Revenue', 'Orders']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {},
                  )
                ],
              ),
              const SizedBox(height: 20),
              Expanded(child: CustomPaint(painter: ChartPainter())),
            ],
          ),
        ),
      ),
      const SizedBox(width: 20),
      Expanded(
        child: Container(
          height: 400,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Icon(Icons.more_vert),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: data.recentOrders.length,
                  itemBuilder: (context, index) {
                    final order = data.recentOrders[index];
                    return _buildOrderItem(order);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildOrderItem(OrdersModel order) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.image, color: Colors.grey),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Vintage Denim Jacket', style: TextStyle(fontWeight: FontWeight.w500)),
              Text('#${order.shortOrderId}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatDate(order.orderDate),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(order.orderStatus),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(order.orderStatus, style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ],
        ),
      ],
    ),
  );

  Color _getStatusColor(String status) {
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

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
