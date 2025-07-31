import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../../model/order_model.dart';
import '../dashboard/admin_dashboard_controller.dart';
import 'admin_report_controller.dart';

class MonthlySalesReport {
  final AdminReportController _controller = AdminReportController();

  String _formatChange(int change) {
    if (change == 0) return 'remained the same';
    return change > 0
        ? 'increased by $change%'
        : 'decreased by ${change.abs()}%';
  }


  Future<void> generateMonthlySalesReport(


      BuildContext context,
      DateTime selectedMonth,
      Function(bool) setIsGenerating,
      ) async {
    setIsGenerating(true);

    try {
      // Fetch real data from dashboard controller
      final stats = await _controller.fetchDashboardStats(
        filterType: DateFilterType.month,
        selectedDate: selectedMonth,
      );

      // Fetch category-wise sales data
      final categoryData = await _fetchCategorySales(selectedMonth);
      print('Revenue Change: ${stats.revenueChange}');
      print('Order Change: ${stats.orderChange}');
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(40),
          build: (context) => [
            _buildPdfHeader(
              'MONTHLY SALES SUMMARY REPORT',
              DateFormat('MMMM yyyy').format(selectedMonth).toUpperCase(),
            ),
            pw.SizedBox(height: 20),

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
                'This report provides a comprehensive analysis of sales performance for ${DateFormat('MMMM yyyy').format(selectedMonth)}. '
                    'Total revenue generated was RM${stats.totalRevenue.toStringAsFixed(2)} from ${stats.allOrders} orders, '
                    'with an average order value of RM${stats.allOrders > 0 ? (stats.totalRevenue / stats.allOrders).toStringAsFixed(2) : "0.00"}. '
                    'Revenue ${_formatChange(stats.revenueChange)}, '
                    'Orders ${_formatChange(stats.orderChange)}, '
                    'and Customer registrations ${_formatChange(stats.customerChange)} compared to the previous month.',

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
                    _buildTableHeader('Comparison'),
                  ],
                ),
                _buildKPIRow(
                  'Total Revenue',
                  'RM${stats.totalRevenue.toStringAsFixed(2)}',
                  stats.revenueChange, // <-- pass int directly
                  stats.revenueChange >= 0,
                ),
                _buildKPIRow(
                  'Total Orders',
                  '${stats.allOrders}',
                  stats.orderChange, // <-- pass int directly
                  stats.orderChange >= 0,
                ),
                _buildKPIRow(
                  'Average Order Value',
                  'RM${stats.allOrders > 0 ? (stats.totalRevenue / stats.allOrders).toStringAsFixed(2) : "0.00"}',
                  null, // <-- no change value, show N/A
                  true,
                ),
                _buildKPIRow(
                  'Order Completion Rate',
                  '${stats.allOrders > 0 ? ((stats.completedOrders / stats.allOrders) * 100).toStringAsFixed(1) : "0"}%',
                  null, // <-- no change value, show N/A
                  stats.completedOrders > stats.cancelledOrders,
                ),

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
                ...categoryData.entries
                    .map((entry) => _buildCategoryRow(
                  entry.key,
                  entry.value['units'].toString(),
                  entry.value['revenue'].toStringAsFixed(2),
                  ((entry.value['revenue'] / stats.totalRevenue) * 100).toStringAsFixed(1),
                  (entry.value['revenue'] / entry.value['units']).toStringAsFixed(2),
                ))
                    .toList(),
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
                _buildStatusBox('Preparing', stats.to_ship_orders ?? 0, stats.allOrders ?? 1),
                _buildStatusBox('In Transit', stats.to_receive_orders ?? 0, stats.allOrders ?? 1),
                _buildStatusBox('Delivered', stats.completedOrders ?? 0, stats.allOrders ?? 1),
                _buildStatusBox('Cancelled', stats.cancelledOrders ?? 0, stats.allOrders ?? 1),
              ],
            ),

            pw.SizedBox(height: 30),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'monthly_sales_report_${DateFormat('yyyy_MM').format(selectedMonth)}.pdf',
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
              'Created By: HY Admin',
              style: pw.TextStyle(fontSize: 11,  color: PdfColors.grey600),
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

  pw.TableRow _buildKPIRow(String metric, String value, int? changeValue, bool isPositive) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(metric, style: pw.TextStyle(fontSize: 11)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(
            changeValue == null
                ? 'N/A'
                : '${changeValue >= 0 ? '+' : ''}${changeValue}%',
            style: pw.TextStyle(
              fontSize: 11,
              color: changeValue == null
                  ? PdfColors.black
                  : (isPositive ? PdfColors.green : PdfColors.red),
            ),
          ),
        ),
      ],
    );
  }

  pw.TableRow _buildCategoryRow(
      String category,
      String units,
      String revenue,
      String percentage,
      String avgPrice,
      ) {
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

  pw.Widget _buildSalesDistributionChart(Map<String, dynamic> categoryData, int totalRevenue) {
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
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
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
}