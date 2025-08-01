import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../../../model/order_model.dart';
import '../dashboard/admin_dashboard_controller.dart';
import 'admin_report_controller.dart';

class DailySalesReport {
  final AdminReportController _controller = AdminReportController();

  Future<void> generateDailySalesReport(
      BuildContext context,
      DateTime selectedDate,
      Function(bool) setIsGenerating,
      ) async {
    setIsGenerating(true);

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
          build: (context) => [
            _buildPdfHeader(
              'DAILY SALES REPORT',
              DateFormat('dd MMMM yyyy').format(selectedDate).toUpperCase(),
            ),
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
                _buildDailySummaryBox(
                  'Total Revenue',
                  'RM${orders.fold(0.0, (sum, order) => sum + order.totalAmount).toStringAsFixed(2)}',
                ),
                _buildDailySummaryBox(
                  'Average Order',
                  'RM${orders.isNotEmpty ? (orders.fold(0.0, (sum, order) => sum + order.totalAmount) / orders.length).toStringAsFixed(2) : "0.00"}',
                ),
                //_buildDailySummaryBox(
                //                   'Completion Rate',
                //                   '${orders.isNotEmpty ? ((orders.where((o) => o.orderStatus == 'completed').length / orders.length) * 100).toStringAsFixed(0) : "0"}%',
                //                 ),
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
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'daily_sales_report_${DateFormat('yyyy_MM_dd').format(selectedDate)}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    } finally {
      setIsGenerating(false);
    }
  }

  // Helper methods for fetching data
  Future<List<OrdersModel>> _fetchDayOrders(DateTime date) async {
    final startDate = DateTime(date.year, date.month, date.day);
    final endDate = startDate.add(Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('order')
        .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('orderDate', isLessThan: Timestamp.fromDate(endDate))
        .orderBy('orderDate')
        .get();

    return snapshot.docs.map((doc) => OrdersModel.fromJson(doc.data(), doc.id)).toList();
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
              'Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
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
          child: pw.Text('#${order.shortOrderId}', style: pw.TextStyle(fontSize: 8)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            DateFormat('HH:mm').format(order.orderDate),
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            order.customerId ?? 'N/A',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            '${order.totalProduct} items',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text('${order.totalProduct}', style: pw.TextStyle(fontSize: 8)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            'RM${(order.totalAmount / order.totalProduct).toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            'RM${order.totalAmount.toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            _getStatusShort(order.orderStatus),
            style: pw.TextStyle(fontSize: 8),
          ),
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

    final maxOrders = hourlyData.values.isEmpty ? 1 : hourlyData.values.reduce(math.max);

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
}