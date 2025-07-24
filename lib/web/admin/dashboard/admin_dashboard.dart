// admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/web/admin/dashboard/small_order_card.dart';
import '../../../model/order_model.dart';
import '../../../model/order_product_model.dart';
import '../widget/blinkingdot.dart';
import '../widget/topbar.dart';
import 'admin_dashboard_controller.dart';
import 'chart_painter.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _controller = AdminDashboardController();
  DashboardStats? data;
  bool loading = true;

  // Enhanced filter variables
  DateFilterType _selectedFilter = DateFilterType.day;
  StatusDateFilterType _statusFilter = StatusDateFilterType.created;
  DateTime _selectedDate = DateTime.now();
  bool _showActiveStatusView = false; // Toggle between period/active view

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
        statusFilter: _statusFilter,
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
    if (loading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading dashboard data...'),
            ],
          ),
        ),
      );
    }

    // Handle case where data might be null
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
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const CustomTopBar(
                  title: 'Dashboard',
                ),
                _buildDateFilterBar(),
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

  Widget _buildDateFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
      child: Column(
        children: [
          Row(
            children: [
              // Date Filter Type Selection
              Row(
                children: [
                  _buildFilterTypeButton('All', DateFilterType.all),
                  const SizedBox(width: 10),
                  _buildFilterTypeButton('Day', DateFilterType.day),
                  const SizedBox(width: 10),
                  _buildFilterTypeButton('Month', DateFilterType.month),
                  const SizedBox(width: 10),
                  _buildFilterTypeButton('Year', DateFilterType.year),
                ],
              ),
              const SizedBox(width: 20),

              // Date Picker (hide when "All" is selected)
              if (_selectedFilter != DateFilterType.all)
                InkWell(
                  onTap: () async {
                    if (_selectedFilter == DateFilterType.day) {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        _selectedDate = date;
                        _loadData();
                      }
                    } else if (_selectedFilter == DateFilterType.month) {
                      _showMonthPicker();
                    } else {
                      _showYearPicker();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
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
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                      ],
                    ),
                  ),
                ),

              const Spacer(),

              // Status Activity Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showActiveStatusView = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: !_showActiveStatusView ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Period View',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: !_showActiveStatusView ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _showActiveStatusView = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _showActiveStatusView ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Active Status',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _showActiveStatusView ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Overdue indicator
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${data!.overdueOrders} overdue orders need attention'),
                      action: SnackBarAction(
                        label: 'View',
                        onPressed: () {
                          // Navigate to orders page with overdue filter
                        },
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: data!.overdueOrders > 0
                        ? Border.all(color: Colors.orange[200]!, width: 1)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Overdue: ${data!.overdueOrders}',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      if (data!.overdueOrders > 0) ...[
                        const SizedBox(width: 4),
                        const BlinkingDot(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Status filter dropdown (when not showing All or Active view)
          if (_selectedFilter != DateFilterType.all && !_showActiveStatusView)
            Container(
              margin: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Text('Filter by: ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<StatusDateFilterType>(
                      value: _statusFilter,
                      underline: const SizedBox(),
                      isDense: true,
                      items: const [
                        DropdownMenuItem(
                          value: StatusDateFilterType.created,
                          child: Text('Orders Created', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: StatusDateFilterType.shipped,
                          child: Text('Orders Shipped', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: StatusDateFilterType.completed,
                          child: Text('Orders Completed', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: StatusDateFilterType.statusChanged,
                          child: Text('Status Changes', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _statusFilter = value);
                          _loadData();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterTypeButton(String label, DateFilterType type) {
    final isSelected = _selectedFilter == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = type;
        });
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
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


  // Enhanced stats display
  Widget _buildStats() => Column(
    children: [
      // Performance metrics row (new)
      if (data!.performanceMetrics.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[50]!, Colors.purple[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem(
                'Avg Processing',
                '${(data!.performanceMetrics['avgProcessingHours'] ?? 0) / 24} days',
                Icons.speed,
              ),
              _buildMetricItem(
                'Avg Shipping',
                '${(data!.performanceMetrics['avgShippingHours'] ?? 0) / 24} days',
                Icons.local_shipping,
              ),
              _buildMetricItem(
                'Fulfillment Rate',
                '${data!.performanceMetrics['fulfillmentRate'] ?? 0}%',
                Icons.check_circle_outline,
              ),
            ],
          ),
        ),

      // First row - Overview metrics
      Row(
        children: [
          _buildStatCard(
            'Total Orders',
            '${data!.allOrders}',
            data!.orderChange,
            Icons.shopping_bag,
            Colors.blue,
            isHighlighted: data!.orderChange > 0,
            subtitle: _getOrdersSubtitle(),
          ),
          const SizedBox(width: 20),
          _buildStatCard(
            'Total Revenue',
            'RM${data!.totalRevenue}',
            data!.revenueChange,
            Icons.attach_money,
            Colors.green,
            isHighlighted: data!.revenueChange > 0,
          ),
          const SizedBox(width: 20),
          _buildStatCard(
            'Avg Order Value',
            'RM${data!.allOrders > 0 ? (data!.totalRevenue / data!.allOrders).toStringAsFixed(2) : "0.00"}',
            0,
            Icons.trending_up,
            Colors.purple,
          ),
        ],
      ),
      const SizedBox(height: 20),

      // Second row - Order status breakdown with enhanced display
      Row(
        children: [
          _buildEnhancedStatCard(
            'To Ship',
            _showActiveStatusView ? '${data!.activeToShipOrders}' : '${data!.to_ship_orders}',
            '${data!.activeToShipOrders}',
            0,
            Icons.local_shipping,
            Colors.orange,
            subtitle: _showActiveStatusView ? 'Currently awaiting shipment' : _getStatusSubtitle('to_ship'),
            showBadge: data!.activeToShipOrders > 0,
            showActiveCount: !_showActiveStatusView && data!.to_ship_orders != data!.activeToShipOrders,
          ),
          const SizedBox(width: 20),
          _buildEnhancedStatCard(
            'To Receive',
            _showActiveStatusView ? '${data!.activeToReceiveOrders}' : '${data!.to_receive_orders}',
            '${data!.activeToReceiveOrders}',
            0,
            Icons.airport_shuttle,
            Colors.blue[700]!,
            subtitle: _showActiveStatusView ? 'Currently in transit' : _getStatusSubtitle('to_receive'),
            showBadge: data!.activeToReceiveOrders > 0,
            showActiveCount: !_showActiveStatusView && data!.to_receive_orders != data!.activeToReceiveOrders,
          ),
          const SizedBox(width: 20),
          _buildStatCard(
            'Completed',
            '${data!.completedOrders}',
            0,
            Icons.check_circle,
            Colors.green,
            subtitle: _getStatusSubtitle('completed'),
          ),
          const SizedBox(width: 20),
          _buildStatCard(
            'Cancelled',
            '${data!.cancelledOrders}',
            0,
            Icons.cancel,
            Colors.red,
            subtitle: _getStatusSubtitle('cancelled'),
          ),
        ],
      ),

      // Activity summary row (new)
      if (data!.statusActivity.isNotEmpty && _selectedFilter != DateFilterType.all)
        Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Activity Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActivityItem('Created', data!.statusActivity['created'] ?? 0, Colors.blue),
                  _buildActivityItem('Shipped', data!.statusActivity['shipped'] ?? 0, Colors.orange),
                  _buildActivityItem('Delivered', data!.statusActivity['completed'] ?? 0, Colors.green),
                ],
              ),
            ],
          ),
        ),
    ],
  );

  Widget _buildStatCard(
      String title,
      String value,
      int change,
      IconData icon,
      Color color,
      {bool isHighlighted = false,
        String? subtitle,
        bool showBadge = false}
      ) => Expanded(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isHighlighted ? Border.all(color: color.withOpacity(0.3), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: isHighlighted ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
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
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  if (showBadge)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
              if (change != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: change > 0 ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        change > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: change > 0 ? Colors.green[700] : Colors.red[700],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${change > 0 ? "+" : ""}${change.abs()}${title.contains('Revenue') ? "%" : ""}',
                        style: TextStyle(
                          color: change > 0 ? Colors.green[700] : Colors.red[700],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          if (subtitle != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
            ),
          if (isHighlighted && change > 0)
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: Text(
                'vs previous period',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _buildEnhancedStatCard(
      String title,
      String value,
      String activeValue,
      int change,
      IconData icon,
      Color color, {
        bool isHighlighted = false,
        String? subtitle,
        bool showBadge = false,
        bool showActiveCount = false,
      }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isHighlighted ? Border.all(color: color.withOpacity(0.3), width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: isHighlighted ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
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
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    if (showBadge)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
                if (change != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: change > 0 ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          change > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 12,
                          color: change > 0 ? Colors.green[700] : Colors.red[700],
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${change > 0 ? "+" : ""}${change.abs()}',
                          style: TextStyle(
                            color: change > 0 ? Colors.green[700] : Colors.red[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 5),

            // Enhanced value display
            if (showActiveCount && value != activeValue) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(
                    ' / ',
                    style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                  ),
                  Text(
                    activeValue,
                    style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text(
                'Period / All active',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ] else
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

            if (subtitle != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue[700], size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
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

  String _getOrdersSubtitle() {
    switch (_statusFilter) {
      case StatusDateFilterType.created:
        return 'Orders created ${_getPeriodText()}';
      case StatusDateFilterType.shipped:
        return 'Orders shipped ${_getPeriodText()}';
      case StatusDateFilterType.completed:
        return 'Orders completed ${_getPeriodText()}';
      case StatusDateFilterType.statusChanged:
        return 'Status changes ${_getPeriodText()}';
    }
  }

  String _getStatusSubtitle(String status) {
    if (_showActiveStatusView) {
      switch (status) {
        case 'to_ship':
          return 'Currently awaiting shipment';
        case 'to_receive':
          return 'Currently in transit';
        case 'completed':
          return 'Successfully delivered';
        case 'cancelled':
          return 'Order cancelled';
        default:
          return '';
      }
    } else {
      return '${_getPeriodText()}';
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
                  const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                children: [
                  Row(
                    children: [
                      const Text('Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  const Icon(Icons.more_vert),
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
                      // Return a simple version without the doc
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
        ),
      ),
    ],
  );

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
}

