import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'admin_dashboard_controller.dart'; // Import for DateFilterType

class RevenueTrendChart extends StatefulWidget {
  final DateFilterType filterType;
  final DateTime selectedDate;

  const RevenueTrendChart({
    Key? key,
    required this.filterType,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<RevenueTrendChart> createState() => _RevenueTrendChartState();
}

class _RevenueTrendChartState extends State<RevenueTrendChart> {
  List<FlSpot> revenueSpots = [];
  List<String> dateLabels = [];
  bool isLoading = true;
  double totalRevenue = 0;
  double maxY = 1000;
  int dataPoints = 7; // Show last 7 days/months

  @override
  void initState() {
    super.initState();
    _loadChartData();
  }

  @override
  void didUpdateWidget(RevenueTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterType != widget.filterType ||
        oldWidget.selectedDate != widget.selectedDate) {
      _loadChartData();
    }
  }

  Future<void> _loadChartData() async {
    setState(() => isLoading = true);

    try {
      // Determine how many days to show based on filter
      DateTime endDate = DateTime.now();
      DateTime startDate;

      switch (widget.filterType) {
        case DateFilterType.day:
        case DateFilterType.month:
        // Show last 7 days
          dataPoints = 7;
          startDate = endDate.subtract(const Duration(days: 7));
          break;
        case DateFilterType.year:
        case DateFilterType.all:
        // Show last 12 months
          dataPoints = 12;
          startDate = DateTime(endDate.year, endDate.month - 12, endDate.day);
          break;
      }

      print('🔍 Fetching completed orders...');
      print('📅 Date range: ${startDate.toIso8601String()} → ${endDate.toIso8601String()}');

      // Fetch completed orders only (actual revenue)
      final ordersSnapshot = await FirebaseFirestore.instance
          .collectionGroup('order')
          .where('orderStatus', isEqualTo: 'completed')
          .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('orderDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('orderDate')
          .get();


      for (var doc in ordersSnapshot.docs.take(3)) {
        final data = doc.data();
        print('🧾 Order ID: ${doc.id}, Date: ${data['orderDate']}, Total: ${data['totalAmount']}');
      }

      print('✅ Retrieved ${ordersSnapshot.docs.length} completed orders');

      // Group revenue by day/month
      Map<String, double> revenueByPeriod = {};

      // Initialize all periods with 0
      for (int i = 0; i < dataPoints; i++) {
        DateTime date;
        String key;

        if (widget.filterType == DateFilterType.year || widget.filterType == DateFilterType.all) {
          // Monthly grouping
          date = DateTime(endDate.year, endDate.month - (dataPoints - 1 - i), 1);
          key = DateFormat('MMM').format(date);
        } else {
          // Daily grouping
          date = endDate.subtract(Duration(days: dataPoints - 1 - i));
          key = DateFormat('d/M').format(date);
        }

        revenueByPeriod[key] = 0;
        dateLabels.add(key);
      }

      // Sum revenue for each period
      for (var doc in ordersSnapshot.docs) {
        final order = doc.data();
        final orderDate = (order['orderDate'] as Timestamp).toDate();
        final amount = (order['totalAmount'] ?? 0).toDouble();

        String key;
        if (widget.filterType == DateFilterType.year || widget.filterType == DateFilterType.all) {
          key = DateFormat('MMM').format(orderDate);
        } else {
          key = DateFormat('d/M').format(orderDate);
        }

        if (revenueByPeriod.containsKey(key)) {
          revenueByPeriod[key] = revenueByPeriod[key]! + amount;
        }
      }

      // Convert to FlSpots
      revenueSpots = [];
      double maxRevenue = 0;
      totalRevenue = 0;

      for (int i = 0; i < dateLabels.length; i++) {
        double revenue = revenueByPeriod[dateLabels[i]] ?? 0;
        revenueSpots.add(FlSpot(i.toDouble(), revenue));
        maxRevenue = revenue > maxRevenue ? revenue : maxRevenue;
        totalRevenue += revenue;
      }

      // Set max Y with padding
      maxY = maxRevenue > 0 ? maxRevenue * 1.2 : 1000;

      setState(() => isLoading = false);
    } catch (e) {
      print('Error loading revenue data: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 320,
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
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    String periodText = widget.filterType == DateFilterType.year || widget.filterType == DateFilterType.all
        ? 'Last 12 Months'
        : 'Last 7 Days';

    return Container(
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revenue Trend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Completed orders - $periodText',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'RM ${NumberFormat('#,##0').format(totalRevenue)}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Simple Line Chart
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[200]!,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        return Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(0)}k'
                              : value.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= dateLabels.length) return const SizedBox();

                        // Show every other label if too crowded
                        if (dateLabels.length > 7 && index % 2 != 0) return const SizedBox();

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            dateLabels[index],
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (dataPoints - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: revenueSpots,
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: Colors.green,
                          strokeWidth: 1,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.3),
                          Colors.green.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.green[700]!,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          'RM ${NumberFormat('#,##0').format(spot.y)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}