import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:secondsight/view/widgets/return_status_utils.dart';
import 'package:secondsight/view/widgets/user_utils.dart';
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
      // Fetch return data and detailed return requests
      final returnData = await _fetchReturnData(selectedMonth);
      final returnRequests = await _fetchDetailedReturnRequests(selectedMonth);
      final adminName = await _controller.getCurrentAdminName();

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
              adminName,
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
                    'The primary reason for returns was "${returnData['topReason']}" accounting for ${returnData['topReasonPercentage'].toStringAsFixed(1)}% of all returns. '
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
                _buildReturnMetricBox('Return Rate', '${returnData['returnRate'].toStringAsFixed(1)}%'),
                _buildReturnMetricBox(
                  'Avg. Return Value',
                  'RM${(returnData['totalReturns'] ?? 0) > 0
                      ? ((returnData['totalValue'] ?? 0) / returnData['totalReturns']).toStringAsFixed(2)
                      : "0.00"}',
                )
              ],
            ),

            pw.SizedBox(height: 30),

            // ENHANCED: Detailed Return Requests Table
            pw.Text(
              'Return Requests Details',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: pw.FixedColumnWidth(80),   // Return ID
                1: pw.FixedColumnWidth(70),   // Date
                2: pw.FixedColumnWidth(80),   // Customer
                3: pw.FlexColumnWidth(2),     // Reason
                4: pw.FixedColumnWidth(60),   // Value
                5: pw.FlexColumnWidth(1),     // Status
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableHeader('Return ID', fontSize: 9),
                    _buildTableHeader('Date', fontSize: 9),
                    _buildTableHeader('Customer', fontSize: 9),
                    _buildTableHeader('Reason', fontSize: 9),
                    _buildTableHeader('Value', fontSize: 9),
                    _buildTableHeader('Status', fontSize: 9),
                  ],
                ),
                ...returnRequests.map((request) => _buildReturnRequestRow(request)).toList(),
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
            pw.NewPage(),

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

            pw.SizedBox(height: 15),

            // FIXED: Status Breakdown
            pw.Text(
              'Return Request Status Breakdown',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 15),

            _buildDynamicStatusTable(returnData),

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

  pw.Widget _buildDynamicStatusTable(Map<String, dynamic> returnData) {
    // Get the actual status breakdown from return data
    final Map<String, int> actualStatusCounts = {
      'pending_approval': returnData['pending_approval'] ?? 0,
      'approved': returnData['approved'] ?? 0,
      'rejected': returnData['rejected'] ?? 0,
      'completed_inspection': returnData['completed_inspection'] ?? 0,
      'pending_inspection': returnData['pending_inspection'] ?? 0,
      'refunded': returnData['refunded'] ?? 0,
      'not_refunded': returnData['not_refunded'] ?? 0,
      'cancelled': returnData['cancelled'] ?? 0,
    };

    // Remove statuses with 0 counts and sort by count (descending)
    final nonZeroStatuses = actualStatusCounts.entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalReturns = returnData['totalReturns'] ?? 1;
    final safeTotal = totalReturns == 0 ? 1 : totalReturns;

    // If no statuses found, show empty state
    if (nonZeroStatuses.isEmpty) {
      return pw.Container(
        padding: pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.Center(
          child: pw.Text(
            'No return request status data available for this period',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableHeader('Status'),
            _buildTableHeader('Count'),
            _buildTableHeader('Percentage'),
            _buildTableHeader('Notes'),
          ],
        ),
        // Dynamic status rows based on actual data
        ...nonZeroStatuses.map((statusEntry) {
          final status = statusEntry.key;
          final count = statusEntry.value;
          final percentage = ((count / safeTotal) * 100).toStringAsFixed(1);

          return _buildDynamicStatusRow(
            ReturnStatusUtils.getReturnStatusText(status),
            count,
            percentage,
            ReturnStatusUtils.getStatusNotes(status),
          );
        }).toList(),

        // Summary row
        if (nonZeroStatuses.length > 1)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                child: pw.Text(
                  'Total',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                child: pw.Text(
                  '$totalReturns',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                child: pw.Text(
                  '100.0%',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                child: pw.Text(
                  'All return requests',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
      ],
    );
  }

  pw.TableRow _buildDynamicStatusRow(String status, int count, String percentage, String notes) {
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
          child: pw.Text('$percentage%', style: pw.TextStyle(fontSize: 11)),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(notes, style: pw.TextStyle(fontSize: 11)),
        ),
      ],
    );
  }


  // FIXED: Fetch detailed return requests using top-level collection (same as original)
  Future<List<Map<String, dynamic>>> _fetchDetailedReturnRequests(DateTime month) async {
    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime end = DateTime(month.year, month.month + 1, 1);

    try {
      // Use the same approach as original - top-level returnRequests collection
      final querySnapshot = await FirebaseFirestore.instance
          .collection('returnRequests')
          .where('returnDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('returnDate', isLessThan: Timestamp.fromDate(end))
          .get();

      List<Map<String, dynamic>> detailedRequests = [];

      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          detailedRequests.add({
            'id': doc.id,
            'customerId': data['userID'] ?? 'unknown', // Handle different field names
            'returnDate': data['returnDate'] as Timestamp?,
            'returnReason': data['returnReason'] ?? 'Not specified',
            'returnStatus': data['returnStatus'] ?? 'unknown',
            'returnPrice': (data['returnPrice'] as num?)?.toDouble() ?? 0.0,
          });
        } catch (e) {
          continue; // Skip invalid documents
        }
      }

      // Sort by date (newest first)
      detailedRequests.sort((a, b) {
        final dateA = a['returnDate'] as Timestamp?;
        final dateB = b['returnDate'] as Timestamp?;
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

      return detailedRequests;
    } catch (e) {
      print('Error fetching detailed return requests: $e');
      return [];
    }
  }

  // FIXED: Use original working method structure with minor enhancements
// Enhanced _fetchReturnData method with better status tracking
  Future<Map<String, dynamic>> _fetchReturnData(DateTime month) async {
    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime end = DateTime(month.year, month.month + 1, 1);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('returnRequests')
          .where('returnDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('returnDate', isLessThan: Timestamp.fromDate(end))
          .get();

      final List<ReturnRequestModel> returns = [];
      final List<Map<String, dynamic>> rawReturns = []; // Track raw data too

      // Parse documents with error handling
      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data();

          // Store raw data for status analysis
          rawReturns.add({
            'id': doc.id,
            'returnStatus': data['returnStatus'] ?? 'unknown',
            'returnReason': data['returnReason'] ?? 'Not specified',
            'returnPrice': (data['returnPrice'] as num?)?.toDouble() ?? 0.0,
          });

          // Try to parse with ReturnRequestModel
          final returnRequest = ReturnRequestModel.fromDocument(doc);
          if (returnRequest.returnStatus.isNotEmpty && returnRequest.returnReason.isNotEmpty) {
            returns.add(returnRequest);
          }
        } catch (e) {
          print('Error parsing return request ${doc.id}: $e');
          continue;
        }
      }

      final int totalReturns = returns.isNotEmpty ? returns.length : rawReturns.length;
      double totalValue = 0.0;

      // Initialize status counts
      final Map<String, int> statusCounts = {
        'pending_approval': 0,
        'approved': 0,
        'rejected': 0,
        'completed_inspection': 0,
        'pending_inspection': 0,
        'refunded': 0,
        'not_refunded': 0,
        'cancelled': 0,
      };

      final Map<String, int> reasonCounts = {};
      final Map<String, double> reasonValues = {};

      // Process returns data
      if (returns.isNotEmpty) {
        // Use ReturnRequestModel data if available
        for (final returnRequest in returns) {
          final double price = returnRequest.returnPrice;
          final String reason = returnRequest.returnReason;
          final String status = returnRequest.returnStatus.toLowerCase();

          totalValue += price;

          // Enhanced: Better status normalization
          String normalizedStatus = _normalizeStatus(status);
          statusCounts[normalizedStatus] = (statusCounts[normalizedStatus] ?? 0) + 1;

          // Count reasons
          reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
          reasonValues[reason] = (reasonValues[reason] ?? 0.0) + price;
        }
      } else {
        // Fallback to raw data processing
        for (final returnData in rawReturns) {
          final double price = returnData['returnPrice'] ?? 0.0;
          final String reason = returnData['returnReason'] ?? 'Not specified';
          final String status = returnData['returnStatus']?.toString().toLowerCase() ?? 'unknown';

          totalValue += price;

          // Enhanced: Better status normalization
          String normalizedStatus = _normalizeStatus(status);
          statusCounts[normalizedStatus] = (statusCounts[normalizedStatus] ?? 0) + 1;

          // Count reasons
          reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
          reasonValues[reason] = (reasonValues[reason] ?? 0.0) + price;
        }
      }

      // Debug: Print actual status distribution
      print('=== ACTUAL STATUS DISTRIBUTION ===');
      statusCounts.forEach((status, count) {
        if (count > 0) {
          print('$status: $count (${totalReturns > 0 ? ((count / totalReturns) * 100).toStringAsFixed(1) : "0.0"}%)');
        }
      });
      print('Total Returns: $totalReturns');
      print('=====================================');

      // Calculate return rate
      double returnRate = 0.0;
      try {
        final ordersSnapshot = await FirebaseFirestore.instance
            .collectionGroup('order')
            .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('orderDate', isLessThan: Timestamp.fromDate(end))
            .get();

        final totalOrders = ordersSnapshot.docs.length;
        returnRate = totalOrders > 0 ? (totalReturns / totalOrders) * 100 : 0.0;
      } catch (e) {
        returnRate = totalReturns == 0 ? 0.0 :
        double.parse(((totalReturns / (totalReturns + 100)) * 100).toStringAsFixed(1));
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

      return {
        'totalReturns': totalReturns,
        'totalValue': totalValue,
        'returnRate': returnRate,
        'topReason': topReason,
        'topReasonPercentage': topReasonPercentage,
        // Updated status fields to match your actual statuses
        'pending_approval': statusCounts['pending_approval'] ?? 0,
        'approved': statusCounts['approved'] ?? 0,
        'rejected': statusCounts['rejected'] ?? 0,
        'completed_inspection': statusCounts['completed_inspection'] ?? 0,
        'pending_inspection': statusCounts['pending_inspection'] ?? 0,
        'refunded': statusCounts['refunded'] ?? 0,
        'not_refunded': statusCounts['not_refunded'] ?? 0,
        'cancelled': statusCounts['cancelled'] ?? 0,
        'reasonBreakdown': reasonBreakdown,
        'statusBreakdown': statusCounts,
      };
    } catch (e) {
      print('Error fetching return data: $e');
      return {
        'totalReturns': 0,
        'totalValue': 0.0,
        'returnRate': 0.0,
        'topReason': 'N/A',
        'topReasonPercentage': 0.0,
        'submitted': 0,
        'pending': 0,
        'approved': 0,
        'processing': 0,
        'rejected': 0,
        'completed': 0,
        'cancelled': 0,
        'reasonBreakdown': <String, Map<String, dynamic>>{},
        'statusBreakdown': <String, int>{},
      };
    }
  }

  String _normalizeStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending_approval':
      case 'pending':
      case 'submitted':
      case 'request_submitted':
        return 'pending_approval';
      case 'approved':
      case 'request_approved':
        return 'approved';
      case 'rejected':
      case 'declined':
        return 'rejected';
      case 'completed_inspection':
      case 'completed':
      case 'refund_processed':
        return 'completed_inspection';
      case 'pending_inspection':
      case 'processing':
      case 'in_progress':
        return 'pending_inspection';
      case 'refunded':
        return 'refunded';
      case 'not_refunded':
        return 'not_refunded';
      case 'cancelled':
      case 'canceled':
        return 'cancelled';
      default:
        return 'pending_approval'; // Default fallback
    }
  }

  // NEW: Build return request row for detailed table
  pw.TableRow _buildReturnRequestRow(Map<String, dynamic> request) {
    final returnDate = request['returnDate'] as Timestamp?;
    final customerId = (request['customerId'] as String?) ?? 'unknown';
    final requestId = (request['id'] as String?) ?? 'unknown';


    return pw.TableRow(
      children: [
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            ReturnStatusUtils.shortReturnId(requestId),
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            returnDate != null
                ? DateFormat('dd/MM/yy').format(returnDate.toDate())
                : 'N/A',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
    shortUserId(customerId),
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            (request['returnReason'] as String?) ?? 'Not specified',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            'RM${((request['returnPrice'] as num?) ?? 0.0).toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            ReturnStatusUtils.getReturnStatusText((request['returnStatus'] as String?) ?? 'unknown'),
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
      ],
    );
  }

  // Updated PDF Helper Methods
  pw.Widget _buildPdfHeader(String title, String date, String adminName) {
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
              'Created By: $adminName',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
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
    if (reasonData.isEmpty) {
      return pw.Container(
        height: 150,
        child: pw.Center(
          child: pw.Text(
            'No return data to display',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
        ),
      );
    }

    return pw.Container(
      height: 150,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: reasonData.entries.map((entry) {
          final percentage = totalReturns > 0 ? (entry.value['count'] ?? 0) / totalReturns : 0.0;

          // Safe string handling for reason labels - This could also cause the error!
          String displayReason;
          try {
            if (entry.key.length > 10) {
              displayReason = '${entry.key.substring(0, 8)}...';
            } else {
              displayReason = entry.key;
            }
          } catch (e) {
            print('Error processing reason text: $e');
            displayReason = entry.key.isNotEmpty ? entry.key : 'Unknown';
          }

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
                    displayReason,
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
    final safeTotal = total == 0 ? 1 : total;
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
}