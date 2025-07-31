import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../dashboard/admin_dashboard_controller.dart';
import '../../../model/order_model.dart';
import 'admin_report_controller.dart';

class AdminReportPage extends StatefulWidget {
  @override
  _AdminReportPageState createState() => _AdminReportPageState();
}

class _AdminReportPageState extends State<AdminReportPage> {
  DateTime selectedMonth = DateTime.now();
  DateTime selectedDate = DateTime.now();
  bool isGenerating = false;
  final _controller = AdminDashboardController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Report Generation'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate Reports',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Select and generate various business reports in PDF format',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 32),

            _buildReportCard(
              title: 'Monthly Sales Summary Report',
              description: 'Comprehensive overview of monthly sales performance including total sales, orders, growth metrics, and category breakdown',
              icon: Icons.analytics_outlined,
              color: Colors.blue,
              onGenerate: () => _generateMonthlySalesReport(),
              dateSelector: _buildMonthSelector(),
            ),

            SizedBox(height: 16),

            _buildReportCard(
              title: 'Daily Sales Report',
              description: 'Detailed breakdown of daily transactions including order details, customer information, and order status',
              icon: Icons.receipt_long_outlined,
              color: Colors.green,
              onGenerate: () => _generateDailySalesReport(),
              dateSelector: _buildDateSelector(),
            ),

            SizedBox(height: 16),

            _buildReportCard(
              title: 'Monthly Return Request Report',
              description: 'Analysis of return requests including total returns, return rate, reasons for returns, and status breakdown',
              icon: Icons.assignment_return_outlined,
              color: Colors.orange,
              onGenerate: () => _generateMonthlyReturnReport(),
              dateSelector: _buildMonthSelector(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onGenerate,
    required Widget dateSelector,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                dateSelector,
                ElevatedButton.icon(
                  onPressed: isGenerating ? null : onGenerate,
                  icon: isGenerating
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Icon(Icons.picture_as_pdf),
                  label: Text('Generate PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      children: [
        Text('Month: ', style: TextStyle(fontWeight: FontWeight.w500)),
        TextButton.icon(
          onPressed: () => _selectMonth(context),
          icon: Icon(Icons.calendar_today, size: 18),
          label: Text(DateFormat('MMMM yyyy').format(selectedMonth)),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Row(
      children: [
        Text('Date: ', style: TextStyle(fontWeight: FontWeight.w500)),
        TextButton.icon(
          onPressed: () => _selectDate(context),
          icon: Icon(Icons.calendar_today, size: 18),
          label: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
        ),
      ],
    );
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && picked != selectedMonth) {
      setState(() {
        selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _generateMonthlySalesReport() async {
    setState(() => isGenerating = true);

    try {
      // Fetch real data from dashboard controller
      final stats = await _controller.fetchDashboardStats(
        filterType: DateFilterType.month,
        selectedDate: selectedMonth,
      );

      // Fetch category-wise sales data
      final categoryData = await _fetchCategorySales(selectedMonth);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(40),
          build: (context) =>
          [
            _buildPdfHeader('MONTHLY SALES SUMMARY REPORT',
                DateFormat('MMMM yyyy').format(selectedMonth).toUpperCase()),
            pw.SizedBox(height: 30),

            // Executive Summary
            pw.Text(
              'Executive Summary',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              ),
              child: pw.Text(
                'This report provides a comprehensive analysis of sales performance for ${DateFormat(
                    'MMMM yyyy').format(selectedMonth)}. '
                    'Total revenue generated was RM${stats.totalRevenue
                    .toStringAsFixed(2)} from ${stats.allOrders} orders, '
                    'with an average order value of RM${stats.allOrders > 0
                    ? (stats.totalRevenue / stats.allOrders).toStringAsFixed(2)
                    : "0.00"}. '
                    '${stats.orderChange > 0 ? "Sales increased by ${stats
                    .orderChange}% compared to the previous period." : ""}',
                style: pw.TextStyle(fontSize: 11, height: 1.5),
              ),
            ),

            pw.SizedBox(height: 30),

            // Key Performance Indicators
            pw.Text(
              'Key Performance Indicators',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableHeader('Metric'),
                    _buildTableHeader('Value'),
                    _buildTableHeader('Change'),
                    _buildTableHeader('Status'),
                  ],
                ),
                _buildKPIRow('Total Revenue',
                    'RM${stats.totalRevenue.toStringAsFixed(2)}',
                    '${stats.revenueChange > 0 ? "+" : ""}${stats
                        .revenueChange}%', stats.revenueChange >= 0),
                _buildKPIRow('Total Orders', '${stats.allOrders}',
                    '${stats.orderChange > 0 ? "+" : ""}${stats.orderChange}%',
                    stats.orderChange >= 0),
                _buildKPIRow('Average Order Value',
                    'RM${stats.allOrders > 0 ? (stats.totalRevenue /
                        stats.allOrders).toStringAsFixed(2) : "0.00"}',
                    'N/A', true),
                _buildKPIRow('Order Completion Rate',
                    '${stats.allOrders > 0 ? ((stats.completedOrders /
                        stats.allOrders) * 100).toStringAsFixed(1) : "0"}%',
                    'N/A', stats.completedOrders > stats.cancelledOrders),
              ],
            ),

            pw.SizedBox(height: 30),

            // Sales by Category
            pw.Text(
              'Sales Analysis by Category',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(1),
                4: pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableHeader('Category'),
                    _buildTableHeader('Units Sold'),
                    _buildTableHeader('Revenue (RM)'),
                    _buildTableHeader('% of Total'),
                    _buildTableHeader('Avg. Price'),
                  ],
                ),
                ...categoryData.entries.map((entry) =>
                    _buildCategoryRow(
                      entry.key,
                      entry.value['units'].toString(),
                      entry.value['revenue'].toStringAsFixed(2),
                      ((entry.value['revenue'] / stats.totalRevenue) * 100)
                          .toStringAsFixed(1),
                      (entry.value['revenue'] / entry.value['units'])
                          .toStringAsFixed(2),
                    )).toList(),
              ],
            ),

            pw.SizedBox(height: 30),

            // Visual representation - Sales Distribution
            pw.Text(
              'Sales Distribution Visualization',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),

            _buildSalesDistributionChart(categoryData, stats.totalRevenue),

            pw.SizedBox(height: 30),

            // Order Status Analysis
            pw.Text(
              'Order Status Analysis',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusBox(
                    'Completed', stats.completedOrders, stats.allOrders),
                _buildStatusBox(
                    'Cancelled', stats.cancelledOrders, stats.allOrders),
                _buildStatusBox('In Progress',
                    stats.allOrders - stats.completedOrders -
                        stats.cancelledOrders, stats.allOrders),
              ],
            ),

            pw.SizedBox(height: 30),

            // Recommendations
            pw.Text(
              'Strategic Recommendations',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            _buildRecommendations(stats, categoryData),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'monthly_sales_report_${DateFormat('yyyy_MM').format(
            selectedMonth)}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    } finally {
      setState(() => isGenerating = false);
    }
  }

  Future<void> _generateDailySalesReport() async {
    setState(() => isGenerating = true);

    try {
      // Fetch real data
      final stats = await _controller.fetchDashboardStats(
        filterType: DateFilterType.day,
        selectedDate: selectedDate,
      );

      // Fetch detailed orders for the day
      final orders = await _fetchDayOrders(selectedDate);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(40),
          build: (context) =>
          [
            _buildPdfHeader('DAILY SALES REPORT',
                DateFormat('dd MMMM yyyy').format(selectedDate).toUpperCase()),
            pw.SizedBox(height: 30),

            // Daily Summary
            pw.Text(
              'Daily Summary',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildDailySummaryBox('Total Orders', '${orders.length}'),
                _buildDailySummaryBox('Total Revenue',
                    'RM${orders.fold(
                        0.0, (sum, order) => sum + order.totalAmount)
                        .toStringAsFixed(2)}'),
                _buildDailySummaryBox('Average Order',
                    'RM${orders.isNotEmpty ? (orders.fold(
                        0.0, (sum, order) => sum + order.totalAmount) /
                        orders.length).toStringAsFixed(2) : "0.00"}'),
                _buildDailySummaryBox('Completion Rate',
                    '${orders.isNotEmpty
                        ? ((orders
                        .where((o) => o.orderStatus == 'completed')
                        .length / orders.length) * 100).toStringAsFixed(0)
                        : "0"}%'),
              ],
            ),

            pw.SizedBox(height: 30),

            // Transaction Details
            pw.Text(
              'Transaction Details',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: pw.FixedColumnWidth(70),
                1: pw.FixedColumnWidth(60),
                2: pw.FixedColumnWidth(80),
                3: pw.FlexColumnWidth(),
                4: pw.FixedColumnWidth(30),
                5: pw.FixedColumnWidth(50),
                6: pw.FixedColumnWidth(50),
                7: pw.FixedColumnWidth(60),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableHeader('Order ID', fontSize: 9),
                    _buildTableHeader('Time', fontSize: 9),
                    _buildTableHeader('Customer', fontSize: 9),
                    _buildTableHeader('Products', fontSize: 9),
                    _buildTableHeader('Qty', fontSize: 9),
                    _buildTableHeader('Price', fontSize: 9),
                    _buildTableHeader('Total', fontSize: 9),
                    _buildTableHeader('Status', fontSize: 9),
                  ],
                ),
                ...orders.map((order) => _buildOrderRow(order)).toList(),
              ],
            ),

            pw.SizedBox(height: 30),

            // Hourly Distribution
            pw.Text(
              'Hourly Sales Distribution',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),

            _buildHourlyDistributionChart(orders),

            pw.SizedBox(height: 30),

            // Payment Method Analysis
            pw.Text(
              'Payment Method Distribution',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),

            _buildPaymentMethodAnalysis(orders),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'daily_sales_report_${DateFormat('yyyy_MM_dd').format(
            selectedDate)}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    } finally {
      setState(() => isGenerating = false);
    }
  }

  Future<void> _generateMonthlyReturnReport() async {
    setState(() => isGenerating = true);

    try {
      // Fetch return data
      final returnData = await _fetchReturnData(selectedMonth);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(40),
          build: (context) =>
          [
            _buildPdfHeader('MONTHLY RETURN REQUEST REPORT',
                DateFormat('MMMM yyyy').format(selectedMonth).toUpperCase()),
            pw.SizedBox(height: 30),

            // Executive Summary
            pw.Text(
              'Executive Summary',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              ),
              child: pw.Text(
                'This report analyzes return request patterns for ${DateFormat(
                    'MMMM yyyy').format(selectedMonth)}. '
                    'Total return requests: ${returnData['totalReturns']}, '
                    'representing ${returnData['returnRate']}% of total orders. '
                    'The primary reason for returns was "${returnData['topReason']}" accounting for ${returnData['topReasonPercentage']}% of all returns. '
                    'Total value of returned items: RM${returnData['totalValue']
                    .toStringAsFixed(2)}.',
                style: pw.TextStyle(fontSize: 11, height: 1.5),
              ),
            ),

            pw.SizedBox(height: 30),

            // Key Metrics
            pw.Text(
              'Key Return Metrics',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildReturnMetricBox(
                    'Total Returns', '${returnData['totalReturns']}'),
                _buildReturnMetricBox('Return Value',
                    'RM${returnData['totalValue'].toStringAsFixed(2)}'),
                _buildReturnMetricBox(
                    'Return Rate', '${returnData['returnRate']}%'),
                _buildReturnMetricBox('Avg. Return Value',
                    'RM${returnData['totalReturns'] > 0
                        ? (returnData['totalValue'] /
                        returnData['totalReturns']).toStringAsFixed(2)
                        : "0.00"}'),
              ],
            ),

            pw.SizedBox(height: 30),

            // Return Analysis by Reason
            pw.Text(
              'Return Analysis by Reason',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableHeader('Return Reason'),
                    _buildTableHeader('Count'),
                    _buildTableHeader('Percentage'),
                    _buildTableHeader('Total Value (RM)'),
                    _buildTableHeader('Avg. Value (RM)'),
                  ],
                ),
                ...returnData['reasonBreakdown'].entries.map((entry) =>
                    _buildReturnReasonRow(
                      entry.key,
                      entry.value['count'].toString(),
                      '${((entry.value['count'] / returnData['totalReturns']) *
                          100).toStringAsFixed(1)}%',
                      entry.value['value'].toStringAsFixed(2),
                      (entry.value['value'] / entry.value['count'])
                          .toStringAsFixed(2),
                    )
                ).toList(),
              ],
            ),

            pw.SizedBox(height: 30),

            // Visual representation
            pw.Text(
              'Return Reason Distribution',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),

            _buildReturnReasonChart(
                returnData['reasonBreakdown'], returnData['totalReturns']),

            pw.SizedBox(height: 30),

            // Status Breakdown
            pw.Text(
              'Return Request Status Breakdown',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableHeader('Status'),
                    _buildTableHeader('Count'),
                    _buildTableHeader('Percentage'),
                    _buildTableHeader('Processing Time'),
                  ],
                ),
                _buildStatusRow('Approved', returnData['approved'],
                    returnData['totalReturns'], '1-2 days'),
                _buildStatusRow('Pending Review', returnData['pending'],
                    returnData['totalReturns'], '3-5 days'),
                _buildStatusRow('Rejected', returnData['rejected'],
                    returnData['totalReturns'], '1 day'),
              ],
            ),

            pw.SizedBox(height: 30),

            // Recommendations
            pw.Text(
              'Recommendations',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            _buildReturnRecommendations(returnData),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'monthly_return_report_${DateFormat('yyyy_MM').format(
            selectedMonth)}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    } finally {
      setState(() => isGenerating = false);
    }
  }

  // Helper methods for fetching data
  Future<Map<String, dynamic>> _fetchCategorySales(DateTime month) async {
    // This would fetch actual category data from Firestore
    // For now, returning sample data structure
    return {
      'Jackets': {'units': 89, 'revenue': 12460.0},
      'Dresses': {'units': 124, 'revenue': 9920.0},
      'Shirts': {'units': 156, 'revenue': 7800.0},
      'Pants': {'units': 98, 'revenue': 6860.0},
      'Accessories': {'units': 234, 'revenue': 4680.0},
      'Others': {'units': 87, 'revenue': 3958.0},
    };
  }

  Future<List<OrdersModel>> _fetchDayOrders(DateTime date) async {
    final startDate = DateTime(date.year, date.month, date.day);
    final endDate = startDate.add(Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('order')
        .where(
        'orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('orderDate', isLessThan: Timestamp.fromDate(endDate))
        .orderBy('orderDate')
        .get();

    return snapshot.docs
        .map((doc) => OrdersModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<Map<String, dynamic>> _fetchReturnData(DateTime month) async {
    // This would fetch actual return data from Firestore
    // For now, returning sample data structure
    return {
      'totalReturns': 47,
      'totalValue': 3245.0,
      'returnRate': 13.7,
      'topReason': 'Size Issues',
      'topReasonPercentage': 38.3,
      'approved': 35,
      'pending': 8,
      'rejected': 4,
      'reasonBreakdown': {
        'Size Issues': {'count': 18, 'value': 1242.0},
        'Quality Concerns': {'count': 12, 'value': 828.0},
        'Not as Described': {'count': 8, 'value': 552.0},
        'Changed Mind': {'count': 5, 'value': 345.0},
        'Damaged in Transit': {'count': 3, 'value': 207.0},
        'Other': {'count': 1, 'value': 71.0},
      },
    };
  }

  // PDF Helper Methods
  pw.Widget _buildPdfHeader(String title, String date) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Report Period: $date',
              style: pw.TextStyle(fontSize: 12),
            ),
            pw.Text(
              'Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(
                  DateTime.now())}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  pw.Widget _buildTableHeader(String text, {double fontSize = 11}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.TableRow _buildKPIRow(String metric, String value, String change,
      bool isPositive) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(metric, style: pw.TextStyle(fontSize: 11)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(value, style: pw.TextStyle(
              fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(
            change,
            style: pw.TextStyle(
              fontSize: 11,
              color: change == 'N/A' ? PdfColors.black : (isPositive ? PdfColors
                  .green : PdfColors.red),
            ),
          ),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(
            isPositive ? '●' : '●',
            style: pw.TextStyle(
              fontSize: 11,
              color: isPositive ? PdfColors.green : PdfColors.red,
            ),
          ),
        ),
      ],
    );
  }

  pw.TableRow _buildCategoryRow(String category, String units, String revenue,
      String percentage, String avgPrice) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(category, style: pw.TextStyle(fontSize: 11)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(units, style: pw.TextStyle(fontSize: 11)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(revenue, style: pw.TextStyle(fontSize: 11)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text('$percentage%', style: pw.TextStyle(fontSize: 11)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(avgPrice, style: pw.TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  pw.Widget _buildSalesDistributionChart(Map<String, dynamic> categoryData,
      int totalRevenue) {
    return pw.Container(
      height: 200,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: categoryData.entries.map((entry) {
          final percentage = (entry.value['revenue'] / totalRevenue);
          return pw.Expanded(
            child: pw.Container(
              margin: pw.EdgeInsets.symmetric(horizontal: 5),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    height: (150 * percentage).toDouble(),
                    color: PdfColors.grey700,
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    entry.key,
                    style: pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    '${(percentage * 100).toStringAsFixed(1)}%',
                    style: pw.TextStyle(
                        fontSize: 7, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  pw.Widget _buildStatusBox(String status, int count, int total) {
    final percentage = total > 0 ? (count / total * 100) : 0;
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            '$count',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            status,
            style: pw.TextStyle(fontSize: 12),
          ),
          pw.Text(
            '${percentage.toStringAsFixed(1)}%',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildRecommendations(DashboardStats stats,
      Map<String, dynamic> categoryData) {
    final recommendations = <String>[];

    // Analyze data and generate recommendations
    if (stats.cancelledOrders > stats.allOrders * 0.1) {
      recommendations.add(
          '• High cancellation rate detected (${((stats.cancelledOrders /
              stats.allOrders) * 100).toStringAsFixed(
              1)}%). Investigate order fulfillment process and customer communication.');
    }

    if (stats.allOrders > 0 && (stats.totalRevenue / stats.allOrders) < 100) {
      recommendations.add(
          '• Average order value is below RM100. Consider implementing bundle offers or minimum order incentives.');
    }

    // Find underperforming categories
    final lowestCategory = categoryData.entries.reduce((a, b) =>
    a.value['revenue'] < b.value['revenue'] ? a : b);
    recommendations.add('• ${lowestCategory
        .key} shows lowest revenue. Consider promotional campaigns or inventory adjustments for this category.');

    recommendations.add(
        '• Implement customer feedback system to understand purchase motivations and improve product offerings.');

    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: recommendations.map((rec) =>
            pw.Padding(
              padding: pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                  rec, style: pw.TextStyle(fontSize: 11, height: 1.5)),
            )).toList(),
      ),
    );
  }

  pw.Widget _buildDailySummaryBox(String label, String value) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.TableRow _buildOrderRow(OrdersModel order) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
              '#${order.shortOrderId}', style: pw.TextStyle(fontSize: 8)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(DateFormat('HH:mm').format(order.orderDate),
              style: pw.TextStyle(fontSize: 8)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
              order.customerId ?? 'N/A', style: pw.TextStyle(fontSize: 8)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
              '${order.totalProduct} items', style: pw.TextStyle(fontSize: 8)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
              '${order.totalProduct}', style: pw.TextStyle(fontSize: 8)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
              'RM${(order.totalAmount / order.totalProduct).toStringAsFixed(
                  2)}', style: pw.TextStyle(fontSize: 8)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text('RM${order.totalAmount.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 8)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(_getStatusShort(order.orderStatus),
              style: pw.TextStyle(fontSize: 8)),
        ),
      ],
    );
  }

  String _getStatusShort(String status) {
    switch (status) {
      case 'completed':
        return 'Done';
      case 'to_ship':
        return 'Ship';
      case 'to_receive':
        return 'Transit';
      case 'cancelled':
        return 'Cancel';
      default:
        return status;
    }
  }

  pw.Widget _buildHourlyDistributionChart(List<OrdersModel> orders) {
    // Group orders by hour
    final hourlyData = <int, int>{};
    for (var i = 0; i < 24; i++) {
      hourlyData[i] = 0;
    }

    for (var order in orders) {
      final hour = order.orderDate.hour;
      hourlyData[hour] = (hourlyData[hour] ?? 0) + 1;
    }

    final maxOrders = hourlyData.values.isEmpty ? 1 : hourlyData.values.reduce(
        math.max);

    return pw.Container(
      height: 150,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: List.generate(24, (hour) {
          final count = hourlyData[hour] ?? 0;
          final height = maxOrders > 0 ? (count / maxOrders) * 120 : 0;

          return pw.Expanded(
            child: pw.Container(
              margin: pw.EdgeInsets.symmetric(horizontal: 1),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  if (count > 0)
                    pw.Container(
                      height: height?.toDouble(),
                      color: PdfColors.grey700,
                    ),
                  pw.SizedBox(height: 5),
                  if (hour % 3 == 0)
                    pw.Text(
                      '$hour',
                      style: pw.TextStyle(fontSize: 7),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  pw.Widget _buildPaymentMethodAnalysis(List<OrdersModel> orders) {
    final paymentMethods = <String, int>{};

    for (var order in orders) {
      final method = order.payment ?? 'Unknown';
      paymentMethods[method] = (paymentMethods[method] ?? 0) + 1;
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableHeader('Payment Method'),
            _buildTableHeader('Count'),
            _buildTableHeader('Percentage'),
          ],
        ),
        ...paymentMethods.entries.map((entry) =>
            pw.TableRow(
              children: [
                pw.Container(
                  padding: pw.EdgeInsets.all(8),
                  child: pw.Text(entry.key, style: pw.TextStyle(fontSize: 11)),
                ),
                pw.Container(
                  padding: pw.EdgeInsets.all(8),
                  child: pw.Text(
                      '${entry.value}', style: pw.TextStyle(fontSize: 11)),
                ),
                pw.Container(
                  padding: pw.EdgeInsets.all(8),
                  child: pw.Text(
                    '${((entry.value / orders.length) * 100).toStringAsFixed(
                        1)}%',
                    style: pw.TextStyle(fontSize: 11),
                  ),
                ),
              ],
            )).toList(),
      ],
    );
  }

  pw.Widget _buildReturnMetricBox(String label, String value) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  pw.TableRow _buildReturnReasonRow(String reason, String count,
      String percentage, String value, String avgValue) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(reason, style: pw.TextStyle(fontSize: 11)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(count, style: pw.TextStyle(fontSize: 11)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(percentage, style: pw.TextStyle(fontSize: 11)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 11)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(avgValue, style: pw.TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  pw.Widget _buildReturnReasonChart(Map<String, dynamic> reasonData,
      int totalReturns) {
    return pw.Container(
      height: 150,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: reasonData.entries.map((entry) {
          final percentage = entry.value['count'] / totalReturns;
          return pw.Expanded(
            child: pw.Container(
              margin: pw.EdgeInsets.symmetric(horizontal: 5),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    height: (120 * percentage).toDouble(),
                    color: PdfColors.grey700,
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    entry.key.length > 10
                        ? '${entry.key.substring(0, 8)}...'
                        : entry.key,
                    style: pw.TextStyle(fontSize: 7),
                  ),
                  pw.Text(
                    '${(percentage * 100).toStringAsFixed(1)}%',
                    style: pw.TextStyle(
                        fontSize: 6, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  pw.TableRow _buildStatusRow(String status, int count, int total,
      String processingTime) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(status, style: pw.TextStyle(fontSize: 11)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text('$count', style: pw.TextStyle(fontSize: 11)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(
            '${((count / total) * 100).toStringAsFixed(1)}%',
            style: pw.TextStyle(fontSize: 11),
          ),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(processingTime, style: pw.TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  pw.Widget _buildReturnRecommendations(Map<String, dynamic> returnData) {
    final recommendations = <String>[];

    // Analyze return data
    if (returnData['returnRate'] > 10) {
      recommendations.add(
          '• Return rate exceeds 10%. Immediate action required to identify and address root causes.');
    }

    if (returnData['topReason'] == 'Size Issues') {
      recommendations.add(
          '• Size-related returns are highest. Improve size charts, add detailed measurements, and consider virtual fitting tools.');
    }

    if (returnData['pending'] > returnData['totalReturns'] * 0.2) {
      recommendations.add(
          '• High number of pending returns. Streamline return processing workflow to improve customer satisfaction.');
    }

    recommendations.add(
        '• Implement post-purchase surveys to gather feedback before returns are initiated.');
    recommendations.add(
        '• Consider offering exchange options instead of returns to retain revenue.');
    recommendations.add(
        '• Review product descriptions and photos for items with high return rates.');

    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: recommendations.map((rec) =>
            pw.Padding(
              padding: pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                  rec, style: pw.TextStyle(fontSize: 11, height: 1.5)),
            )).toList(),
      ),
    );
  }
}