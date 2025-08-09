import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../../model/order_model.dart';
import '../../../model/return_request_model.dart';
import '../dashboard/admin_dashboard_controller.dart';
import 'admin_report_controller.dart';

class MonthlyReturnReport {
  final AdminReportController _controller = AdminReportController();

  Future<void> generateMonthlyReturnReport(
      BuildContext context,
      DateTime selectedMonth,
      Function(bool) setIsGenerating,
      ) async {

    setIsGenerating(true);

    try {
      // Fetch return data
      final returnData = await _fetchReturnData(selectedMonth);

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(40),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
          build: (context) => [
            _buildPdfHeader(
              'MONTHLY RETURN REQUEST REPORT',
              DateFormat('MMMM yyyy').format(selectedMonth).toUpperCase(),
            ),
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
                'This report analyzes return request patterns for ${DateFormat('MMMM yyyy').format(selectedMonth)}. '
                    'Total return requests: ${returnData['totalReturns']}, '
                    'representing ${returnData['returnRate']}% of total orders. '
                    'The primary reason for returns was "${returnData['topReason']}" accounting for ${returnData['topReasonPercentage']}% of all returns. '
                    'Total value of returned items: RM${returnData['totalValue'].toStringAsFixed(2)}.',
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
                _buildReturnMetricBox('Total Returns', '${returnData['totalReturns']}'),
                _buildReturnMetricBox('Return Value', 'RM${returnData['totalValue'].toStringAsFixed(2)}'),
                _buildReturnMetricBox('Return Rate', '${returnData['returnRate']}%'),
                _buildReturnMetricBox(
                  'Avg. Return Value',
                  'RM${(returnData['totalReturns'] ?? 0) > 0
                      ? ((returnData['totalValue'] ?? 0) / returnData['totalReturns']).toStringAsFixed(2)
                      : "0.00"}',
                )
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
                ...returnData['reasonBreakdown'].entries.map((entry) {
                  final count = entry.value['count'] ?? 0;
                  final value = entry.value['value'] ?? 0.0;

                  return _buildReturnReasonRow(
                    entry.key,
                    count.toString(),
                    '${(returnData['totalReturns'] ?? 1) > 0 ? ((count / returnData['totalReturns']) * 100).toStringAsFixed(1) : "0.0"}%',
                    value.toStringAsFixed(2),
                    count > 0 ? (value / count).toStringAsFixed(2) : '0.00',
                  );
                }).toList(),
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
              (returnData['reasonBreakdown'] as Map<String, dynamic>?) ?? {},
              returnData['totalReturns'] ?? 0,
            ),

            pw.SizedBox(height: 100),

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
                    _buildTableHeader('Processing Time (test)'),
                  ],
                ),
                _buildStatusRow('Approved', returnData['approved'] ?? 0, returnData['totalReturns'] ?? 1, '1-2 days'),
                _buildStatusRow('Pending Review', returnData['pending'] ?? 0, returnData['totalReturns'] ?? 1, '3-5 days'),
                _buildStatusRow('Rejected', returnData['rejected'] ?? 0, returnData['totalReturns'] ?? 1, '1 day'),
              ],
            ),

            pw.SizedBox(height: 30),
          ],
        ),
      );


      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'monthly_return_report_${DateFormat('yyyy_MM').format(selectedMonth)}.pdf',
      );


    } catch (e, stack) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    } finally {
      setIsGenerating(false);
    }
  }



  Future<Map<String, dynamic>> _fetchReturnData(DateTime month) async {


    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime end = DateTime(month.year, month.month + 1, 1);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('returnRequests') // Use collection instead of collectionGroup
          .where('returnDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('returnDate', isLessThan: Timestamp.fromDate(end))
          .get();

      final List<ReturnRequestModel> returns = [];

      // Parse documents with error handling
      for (final doc in querySnapshot.docs) {
        try {
          final returnRequest = ReturnRequestModel.fromDocument(doc);
          if (returnRequest.returnStatus.isNotEmpty && returnRequest.returnReason.isNotEmpty) {
            returns.add(returnRequest);
          }
        } catch (e) {
          continue; // Skip this document and continue with others
        }
      }

      final int totalReturns = returns.length;
      double totalValue = 0.0;

      final Map<String, int> statusCounts = {
        'pending_approval': 0,
        'approved': 0,
        'rejected': 0,
        'completed': 0,
        'pending_inspection': 0,
        'cancelled': 0,
      };

      final Map<String, int> reasonCounts = {};
      final Map<String, double> reasonValues = {};

      for (final returnRequest in returns) {
        final double price = returnRequest.returnPrice;
        final String reason = returnRequest.returnReason;
        final String status = returnRequest.returnStatus.toLowerCase();

        totalValue += price;

        // Count status - handle different status formats
        String normalizedStatus = status;
        if (status.contains('pending') && status.contains('approval')) {
          normalizedStatus = 'pending_approval';
        } else if (status.contains('pending') && status.contains('inspection')) {
          normalizedStatus = 'pending_inspection';
        }

        if (statusCounts.containsKey(normalizedStatus)) {
          statusCounts[normalizedStatus] = (statusCounts[normalizedStatus] ?? 0) + 1;
        } else {
          // Handle unknown statuses
          statusCounts[normalizedStatus] = 1;
        }

        // Count reasons
        reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
        reasonValues[reason] = (reasonValues[reason] ?? 0.0) + price;
      }

      // Determine top reason
      String topReason = 'N/A';
      double topReasonPercentage = 0.0;
      if (reasonCounts.isNotEmpty && totalReturns > 0) {
        final sortedReasons = reasonCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        if (sortedReasons.isNotEmpty) {
          topReason = sortedReasons.first.key;
          topReasonPercentage = (sortedReasons.first.value / totalReturns) * 100;
        }
      }

      // Format reason breakdown
      final Map<String, Map<String, dynamic>> reasonBreakdown = {};
      for (final reason in reasonCounts.keys) {
        final count = reasonCounts[reason] ?? 0;
        final value = reasonValues[reason] ?? 0.0;
        reasonBreakdown[reason] = {
          'count': count,
          'value': value,
        };
      }

      // Calculate return rate (you may want to adjust this calculation based on total orders)
      final double returnRate = totalReturns == 0 ? 0.0 :
      double.parse(((totalReturns / (totalReturns + 100)) * 100).toStringAsFixed(1)); // Placeholder calculation

      return {
        'totalReturns': totalReturns,
        'totalValue': totalValue,
        'returnRate': returnRate,
        'topReason': topReason,
        'topReasonPercentage': topReasonPercentage,
        'pendingApproval': statusCounts['pending_approval'] ?? 0,
        'approved': statusCounts['approved'] ?? 0,
        'rejected': statusCounts['rejected'] ?? 0,
        'completed': statusCounts['completed'] ?? 0,
        'pendingInspection': statusCounts['pending_inspection'] ?? 0,
        'cancelled': statusCounts['cancelled'] ?? 0,
        'reasonBreakdown': reasonBreakdown,
      };

    } catch (e) {
      // Return empty data structure to prevent null errors
      return {
        'totalReturns': 0,
        'totalValue': 0.0,
        'returnRate': 0.0,
        'topReason': 'N/A',
        'topReasonPercentage': 0.0,
        'pendingApproval': 0,
        'approved': 0,
        'rejected': 0,
        'completed': 0,
        'pendingInspection': 0,
        'cancelled': 0,
        'reasonBreakdown': <String, Map<String, dynamic>>{},
      };
    }
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

  pw.TableRow _buildReturnReasonRow(
      String reason,
      String count,
      String percentage,
      String value,
      String avgValue,
      ) {
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

  pw.Widget _buildReturnReasonChart(Map<String, dynamic> reasonData, int totalReturns) {
    return pw.Container(
      height: 150,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: reasonData.entries.map((entry) {
          final percentage = totalReturns > 0 ? (entry.value['count'] ?? 0) / totalReturns : 0.0;
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
                    entry.key.length > 10 ? '${entry.key.substring(0, 8)}...' : entry.key,
                    style: pw.TextStyle(fontSize: 7),
                  ),
                  pw.Text(
                    '${(percentage * 100).toStringAsFixed(1)}%',
                    style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  pw.TableRow _buildStatusRow(String status, int count, int total, String processingTime) {
    final safeTotal = total == 0 ? 1 : total; // Prevent division by zero
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
            '${((count / safeTotal) * 100).toStringAsFixed(1)}%',
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

  static String getReturnStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending_approval':
        return 'Pending Approval';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      case 'pending_inspection':
        return 'Pending Inspection';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}