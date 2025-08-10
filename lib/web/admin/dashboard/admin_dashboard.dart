// Simplified admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:secondsight/web/admin/dashboard/revenue_trend_chart.dart' hide DateFilterType;
import 'package:secondsight/web/admin/dashboard/small_order_card.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../services/admin_auth_provider.dart';
import '../widget/blinkingdot.dart';
import '../widget/topbar.dart';
import 'admin_dashboard_controller.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _controller = AdminDashboardController();
  DashboardStats? data;
  bool loading = true;

  // Simplified - only date filter
  DateFilterType _selectedFilter = DateFilterType.day;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => loading = true);
      final result = await _controller.fetchDashboardStats(
        filterType: _selectedFilter,
        selectedDate: _selectedDate,
      );
      if (mounted) {
        setState(() {
          data = result;
          loading = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminAuthProvider>(context);

    if (loading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!loading && data == null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load dashboard data'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          const CustomTopBar(title: 'Dashboard'),

          _buildSimplifiedDateFilterBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOperationalStatus(),
                  const SizedBox(height: 30),
                  _buildReturnOperationalStatus(),
                  const SizedBox(height: 30),
                  _buildBusinessMetrics(),
                  const SizedBox(height: 30),
                  _buildRevenueChart(),
                  const SizedBox(height: 30),
                  _buildBottomSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplifiedDateFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Date filter buttons
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _buildFilterButton('All Time', DateFilterType.all),
                _buildFilterButton('Today', DateFilterType.day),
                _buildFilterButton('This Month', DateFilterType.month),
                _buildFilterButton('This Year', DateFilterType.year),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Date picker (except for "All Time")
          if (_selectedFilter != DateFilterType.all)
            InkWell(
              onTap: () => _selectDate(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      _getDateDisplayText(),
                      style: TextStyle(color: Colors.grey[800], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          const Spacer(),

          // Quick stats
          _buildQuickStat('Overdue', data!.overdueOrders, Colors.orange),
          const SizedBox(width: 12),
          _buildQuickStat('Customers', data!.totalCustomers, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, DateFilterType type) {
    final isSelected = _selectedFilter == type;
    return InkWell(
      onTap: () {
        setState(() => _selectedFilter = type);
        _loadData();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: value > 0 ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: Colors.black, fontSize: 12),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (label == 'Overdue' && value > 0) ...[
            const SizedBox(width: 4),
            const BlinkingDot(),
          ],
        ],
      ),
    );
  }

  Widget _buildBusinessMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Overview - ${_getPeriodLabel()}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMetricCard(
              title: 'Orders',
              value: '${data!.allOrders}',
              subtitle: 'Created ${_getPeriodText()}',
              icon: Icons.shopping_bag,
              color: Colors.blue,
              change: data!.orderChange,
            ),
            const SizedBox(width: 16),
            _buildMetricCard(
              title: 'Revenue',
              value: 'RM${data!.totalRevenue}',
              subtitle: 'From completed orders',
              icon: Icons.attach_money,
              color: Colors.green,
              change: data!.revenueChange,
              isPercentage: true,
            ),
            const SizedBox(width: 16),
            _buildMetricCard(
              title: 'Avg Order Value',
              value: 'RM${data!.allOrders > 0 ? (data!.totalRevenue / data!.allOrders).toStringAsFixed(2) : "0.00"}',
              subtitle: 'Per order',
              icon: Icons.trending_up,
              color: Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOperationalStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Current Order Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatusCard(
              title: 'To Ship',
              value: '${data!.activeToShipOrders}',
              subtitle: 'Awaiting shipment',
              icon: Icons.inventory_2,
              color: Colors.orange,
              isUrgent: data!.activeToShipOrders > 20,
            ),
            const SizedBox(width: 16),
            _buildStatusCard(
              title: 'In Transit',
              value: '${data!.activeToReceiveOrders}',
              subtitle: 'On the way',
              icon: Icons.local_shipping,
              color: Colors.blue,
            ),
            const SizedBox(width: 16),
            _buildStatusCard(
              title: 'Completed',
              value: '${data!.completedOrders}',
              subtitle: _selectedFilter == DateFilterType.all ? 'All time' : _getPeriodText(),
              icon: Icons.check_circle,
              color: Colors.green,
            ),
            const SizedBox(width: 16),
            _buildStatusCard(
              title: 'Cancelled',
              value: '${data!.cancelledOrders}',
              subtitle: _selectedFilter == DateFilterType.all ? 'All time' : _getPeriodText(),
              icon: Icons.cancel,
              color: Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReturnOperationalStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Current Return Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatusCard(
              title: 'Pending Approval',
              value: '${data!.activeToShipOrders}',
              subtitle: 'Awaiting review',
              icon: Icons.hourglass_top,
              color: Colors.orange,
              isUrgent: data!.activeToShipOrders > 20,
            ),
            const SizedBox(width: 16),
            _buildStatusCard(
              title: 'Pending Inspection',
              value: '${data!.activeToReceiveOrders}',
              subtitle: 'Checking return condition',
              icon: Icons.search,
              color: Colors.blue,
            ),
            const SizedBox(width: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Activity & Performance Dashboard
        Expanded(
          flex: 2,
          child: _buildActivityDashboard(),
        ),
        const SizedBox(width: 20),
        // Recent Orders
        Expanded(
          child: _buildRecentOrders(),
        ),
      ],
    );
  }

  Widget _buildActivityMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityDashboard() {
    return Container(
      height: 650, // Increased height to accommodate more metrics
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Text(
            'Today\'s Activity & Performance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Today's Activity
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActivityMetric(
                  icon: Icons.add_shopping_cart,
                  label: 'New Orders',
                  value: '${data!.statusActivity['created'] ?? 0}',
                  color: Colors.blue,
                ),
                _buildActivityMetric(
                  icon: Icons.local_shipping,
                  label: 'Shipped',
                  value: '${data!.statusActivity['shipped'] ?? 0}',
                  color: Colors.orange,
                ),
                _buildActivityMetric(
                  icon: Icons.check_circle,
                  label: 'Delivered',
                  value: '${data!.statusActivity['completed'] ?? 0}',
                  color: Colors.green,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Performance Metrics
          const Text(
            'Performance Metrics (Based on 200 Most Recent Orders)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildPerformanceRow(
                    icon: Icons.speed,
                    label: 'Avg Processing Time',
                    value: _formatHoursToReadable(data!.performanceMetrics['avgProcessingHours'] ?? 0),
                    benchmark: 'Target: < 24 hours',
                    isGood: (data!.performanceMetrics['avgProcessingHours'] ?? 0) <= 24,
                  ),
                  const SizedBox(height: 16),

                  _buildPerformanceRow(
                    icon: Icons.local_shipping,
                    label: 'Avg Shipping Time',
                    value: _formatMetricValue(data!.performanceMetrics['avgShippingHours']),
                    benchmark: 'Target: < 72 hours',
                    isGood: _isMetricGood('avgShippingHours', data!.performanceMetrics['avgShippingHours']),
                  ),

                  const SizedBox(height: 16),

                  _buildPerformanceRow(
                    icon: Icons.schedule,
                    label: 'Avg Completion Time',
                    value: _formatMetricValue(data!.performanceMetrics['avgCompletionHours']),
                    benchmark: 'Target: < 5 days',
                    isGood: _isMetricGood('avgCompletionHours', data!.performanceMetrics['avgCompletionHours']),
                  ),

                  const SizedBox(height: 16),

                  _buildPerformanceRow(
                    icon: Icons.star,
                    label: 'Fulfillment Rate',
                    value: _formatMetricValue(data!.performanceMetrics['fulfillmentRate'], isPercentage: true),
                    benchmark: 'Target: > 95%',
                    isGood: _isMetricGood('fulfillmentRate', data!.performanceMetrics['fulfillmentRate']),
                  ),
                  const SizedBox(height: 16),

                  _buildPerformanceRow(
                    icon: Icons.flash_on,
                    label: 'Processing Efficiency',
                    value: '${data!.performanceMetrics['processingEfficiency'] ?? 0}%',
                    benchmark: 'Orders processed in 24h',
                    isGood: (data!.performanceMetrics['processingEfficiency'] ?? 0) >= 80,
                  ),
                  const SizedBox(height: 16),

                  _buildPerformanceRow(
                    icon: Icons.cancel_outlined,
                    label: 'Cancellation Rate',
                    value: '${data!.performanceMetrics['cancellationRate'] ?? 0}%',
                    benchmark: 'Target: < 5%',
                    isGood: (data!.performanceMetrics['cancellationRate'] ?? 0) <= 5,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow({
    required IconData icon,
    required String label,
    required String value,
    required String benchmark,
    required bool isGood,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isGood ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGood ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isGood ? Colors.green[100] : Colors.orange[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
                icon,
                color: isGood ? Colors.green[700] : Colors.orange[700],
                size: 16
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500
                    )
                ),
                Text(
                  benchmark,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600]
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isGood ? Colors.green[700] : Colors.orange[700],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isGood ? Icons.check_circle : Icons.warning,
                color: isGood ? Colors.green[600] : Colors.orange[600],
                size: 14,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Container(
      height: 600,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              Row(
                children: [
                  const Text(
                    'Recent Orders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  if (data!.newOrdersCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${data!.newOrdersCount} new',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () {
                  // Navigate to orders page
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: data!.recentOrders.length,
              itemBuilder: (context, index) {
                final order = data!.recentOrders[index];
                final orderDoc = data!.rawOrderDocs.length > index
                    ? data!.rawOrderDocs[index]
                    : null;
                final isNew = order.orderDate.isAfter(
                    DateTime.now().subtract(const Duration(hours: 24))
                );

                if (orderDoc == null) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    child: Text('Order #${order.shortOrderId}'),
                  );
                }

                return _buildOrderItem(order, orderDoc, isNew: isNew);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    int? change,
    bool isPercentage = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (change != null && change != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: change > 0 ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          change > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 12,
                          color: change > 0 ? Colors.green : Colors.red,
                        ),
                        Text(
                          '${change.abs()}${isPercentage ? "%" : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            color: change > 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isUrgent = false,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12), // Reduced from 20
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8), // Reduced from 10
          border: isUrgent ? Border.all(color: color.withOpacity(0.3), width: 1.5) : null, // Reduced width
          boxShadow: [
            BoxShadow(
              color: isUrgent ? color.withOpacity(0.08) : Colors.grey.withOpacity(0.08),
              spreadRadius: 0, // Reduced from 1
              blurRadius: 4, // Reduced from 5
            ),
          ],
        ),
        child: Row( // Changed from Column to Row for horizontal layout
          children: [
            Container(
              padding: const EdgeInsets.all(10), // Slightly increased for better proportion
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24), // Slightly larger icon
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Minimize vertical space
                children: [
                  Row(
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 22, // Reduced from 28
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isUrgent) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2), // Reduced spacing
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13, // Reduced from 14
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10, // Reduced from 11
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(OrdersModel order, DocumentSnapshot orderDoc, {bool isNew = false}) {
    final controller = AdminDashboardController();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: isNew ? const EdgeInsets.all(2) : null,
      decoration: isNew ? BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [Colors.blue.withOpacity(0.1), Colors.transparent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ) : null,
      child: SmallOrderCard(
        order: order,
        orderDoc: orderDoc,
        controller: controller,
        isNew: isNew,
      ),
    );
  }

  Widget _buildRevenueChart() {
    return RevenueTrendChart(
      filterType: _selectedFilter,
      selectedDate: _selectedDate,
    );
  }


  // Helper methods
  String _getPeriodLabel() {
    switch (_selectedFilter) {
      case DateFilterType.day:
        return 'Today';
      case DateFilterType.month:
        return '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}';
      case DateFilterType.year:
        return 'Year ${_selectedDate.year}';
      case DateFilterType.all:
        return 'All Time';
    }
  }

  String _getPeriodText() {
    switch (_selectedFilter) {
      case DateFilterType.day:
        return 'today';
      case DateFilterType.month:
        return 'this month';
      case DateFilterType.year:
        return 'this year';
      case DateFilterType.all:
        return 'all time';
    }
  }

  String _getDateDisplayText() {
    switch (_selectedFilter) {
      case DateFilterType.day:
        return '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
      case DateFilterType.month:
        return '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}';
      case DateFilterType.year:
        return '${_selectedDate.year}';
      case DateFilterType.all:
        return 'All Time';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _formatHoursToReadable(int hours) {
    if (hours == 0) {
      return 'No data';
    } else if (hours < 1) {
      return '< 1 hour';
    } else if (hours < 24) {
      return '$hours hour${hours == 1 ? '' : 's'}';
    } else if (hours < 48) {
      final remainingHours = hours % 24;
      if (remainingHours == 0) {
        return '1 day';
      } else {
        return '1 day ${remainingHours}h';
      }
    } else {
      final days = hours ~/ 24;
      final remainingHours = hours % 24;
      if (remainingHours == 0) {
        return '$days days';
      } else {
        return '$days days ${remainingHours}h';
      }
    }
  }

  String _formatMetricValue(dynamic value, {bool isPercentage = false}) {
    if (value is String) {
      return value; // Return 'No data' as is
    } else if (value is int) {
      if (isPercentage) {
        return '$value%';
      } else {
        return _formatHoursToReadable(value);
      }
    }
    return 'No data';
  }

  bool _isMetricGood(String metricType, dynamic value) {
    if (value is String) {
      return false; // 'No data' is neutral
    } else if (value is int) {
      switch (metricType) {
        case 'avgShippingHours':
          return value <= 72;
        case 'avgCompletionHours':
          return value <= 120;
        case 'fulfillmentRate':
          return value >= 95;
        default:
          return false;
      }
    }
    return false;
  }

// Additional helper method for performance status
  String _getPerformanceStatus(String metric, dynamic value) {
    switch (metric) {
      case 'avgProcessingHours':
        final hours = value as int;
        if (hours == 0) return 'No data';
        if (hours <= 12) return 'Excellent';
        if (hours <= 24) return 'Good';
        if (hours <= 48) return 'Fair';
        return 'Needs improvement';

      case 'avgShippingHours':
        final hours = value as int;
        if (hours == 0) return 'No data';
        if (hours <= 24) return 'Excellent';
        if (hours <= 72) return 'Good';
        if (hours <= 120) return 'Fair';
        return 'Needs improvement';

      case 'fulfillmentRate':
        final rate = value as int;
        if (rate >= 98) return 'Excellent';
        if (rate >= 95) return 'Good';
        if (rate >= 90) return 'Fair';
        return 'Needs improvement';

      case 'processingEfficiency':
        final efficiency = value as int;
        if (efficiency >= 90) return 'Excellent';
        if (efficiency >= 80) return 'Good';
        if (efficiency >= 70) return 'Fair';
        return 'Needs improvement';

      case 'cancellationRate':
        final rate = value as int;
        if (rate <= 2) return 'Excellent';
        if (rate <= 5) return 'Good';
        if (rate <= 10) return 'Fair';
        return 'Needs improvement';

      default:
        return 'Unknown';
    }
  }

  void _selectDate() async {
    if (_selectedFilter == DateFilterType.day) {
      final date = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (date != null) {
        setState(() => _selectedDate = date);
        _loadData();
      }
    } else if (_selectedFilter == DateFilterType.month) {
      _showMonthPicker();
    } else if (_selectedFilter == DateFilterType.year) {
      _showYearPicker();
    }
  }

  void _showMonthPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Month'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDate = DateTime(_selectedDate.year, index + 1);
                    });
                    Navigator.pop(context);
                    _loadData();
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: _selectedDate.month == index + 1 ? Colors.blue : null,
                    ),
                    child: Center(
                      child: Text(
                        _getMonthName(index + 1).substring(0, 3),
                        style: TextStyle(
                          color: _selectedDate.month == index + 1 ? Colors.white : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showYearPicker() {
    showDialog(
      context: context,
      builder: (context) {
        final currentYear = DateTime.now().year;
        return AlertDialog(
          title: const Text('Select Year'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) {
                final year = currentYear - index;
                return ListTile(
                  title: Text('$year'),
                  selected: _selectedDate.year == year,
                  onTap: () {
                    setState(() {
                      _selectedDate = DateTime(year, _selectedDate.month);
                    });
                    Navigator.pop(context);
                    _loadData();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}