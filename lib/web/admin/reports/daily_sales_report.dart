import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:secondsight/view/widgets/product_status_utils.dart';
import '../../../model/order_model.dart';
import '../../../view/widgets/user_utils.dart';
import '../dashboard/admin_dashboard_controller.dart';
import 'admin_report_controller.dart';

class DailySalesReport {
  final AdminReportController _controller = AdminReportController();
  Map<String, String> _customerNames = {};
  Map<String, List<Map<String, dynamic>>> _orderProducts = {};


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
              'DAILY SALES REPORT',
              DateFormat('dd MMMM yyyy').format(selectedDate).toUpperCase(),
              adminName,
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
                0: pw.FixedColumnWidth(70),    // Order ID
                1: pw.FixedColumnWidth(50),    // Time
                2: pw.FixedColumnWidth(80),    // Customer
                3: pw.FlexColumnWidth(2),      // Product ID/Name
                4: pw.FixedColumnWidth(30),    // Qty (individual product)
                5: pw.FixedColumnWidth(50),    // Price (individual product)
                6: pw.FixedColumnWidth(60),    // Total (order total - only shown on first row)
                7: pw.FixedColumnWidth(50),    // Status (only shown on first row)
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableHeader('Order ID', fontSize: 9),
                    _buildTableHeader('Time', fontSize: 9),
                    _buildTableHeader('Customer', fontSize: 9),
                    _buildTableHeader('Product', fontSize: 9),
                    _buildTableHeader('Qty', fontSize: 9),
                    _buildTableHeader('Price', fontSize: 9),
                    _buildTableHeader('Order Total', fontSize: 9),
                    _buildTableHeader('Status', fontSize: 9),
                  ],
                ),
                // MODIFIED: Generate rows for each product
                ..._buildProductRows(orders),
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

  List<pw.TableRow> _buildProductRows(List<OrdersModel> orders) {
    List<pw.TableRow> rows = [];

    for (final order in orders) {
      final products = _orderProducts[order.id] ?? [];

      if (products.isEmpty) {
        // If no products, show one row with "No products"
        rows.add(_buildProductRow(
          order: order,
          product: null,
          isFirstProduct: true,
          productCount: 0,
        ));
      } else {
        // Add a row for each product
        for (int i = 0; i < products.length; i++) {
          rows.add(_buildProductRow(
            order: order,
            product: products[i],
            isFirstProduct: i == 0, // Only show order info on first product row
            productCount: products.length,
          ));
        }
      }
    }

    return rows;
  }

  // NEW: Build individual product row
  pw.TableRow _buildProductRow({
    required OrdersModel order,
    required Map<String, dynamic>? product,
    required bool isFirstProduct,
    required int productCount,
  }) {
    return pw.TableRow(
      children: [
        // Order ID (only show on first product row)
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            isFirstProduct ? '#${order.shortOrderId}' : '',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        // Time (only show on first product row)
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            isFirstProduct ? DateFormat('HH:mm').format(order.orderDate) : '',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        // Customer (only show on first product row)
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            isFirstProduct
                ? shortUserId(_customerNames[order.customerId] ?? order.customerId ?? 'N/A')
                : '',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        // Product ID/Name (show for each product)
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            product != null
                ? '${ProductStatusUtils.shortProductId(product['id'])}'
                : 'No products',
            style: pw.TextStyle(
              fontSize: 8,
              color: product != null ? PdfColors.black : PdfColors.grey600,
            ),
          ),
        ),
        // Individual Product Quantity
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            product != null ? '${product['quantity']}' : '-',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        // Individual Product Price
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            product != null ? 'RM${product['price'].toStringAsFixed(2)}' : '-',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        // Order Total (only show on first product row)
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            isFirstProduct ? 'RM${order.totalAmount.toStringAsFixed(2)}' : '',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ),
        // Order Status (only show on first product row)
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text(
            isFirstProduct ? _getStatusShort(order.orderStatus) : '',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
      ],
    );
  }


  Future<List<OrdersModel>> _fetchDayOrders(DateTime date) async {
    final startDate = DateTime(date.year, date.month, date.day);
    final endDate = startDate.add(Duration(days: 1));

    // Build customer names map
    await _buildCustomerNamesMap();

    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('order')
        .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('orderDate', isLessThan: Timestamp.fromDate(endDate))
        .orderBy('orderDate')
        .get();

    // Process each order and fetch product details
    List<OrdersModel> orders = [];

    for (final doc in snapshot.docs) {
      final userId = doc.reference.parent.parent!.id;
      final order = OrdersModel.fromJson(doc.data(), doc.id);
      final orderWithCustomer = order.copyWith(customerId: userId);

      // Fetch product details for this order
      await _fetchOrderProducts(userId, order.id);

      orders.add(orderWithCustomer);
    }

    return orders;
  }

  // NEW: Fetch product details for a specific order
  Future<void> _fetchOrderProducts(String userId, String orderId) async {
    try {
      final orderProductsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('order')
          .doc(orderId)
          .collection('orderProducts')
          .get();

      List<Map<String, dynamic>> productDetails = [];

      for (final orderProductDoc in orderProductsSnapshot.docs) {
        final orderProductData = orderProductDoc.data();
        final productRef = orderProductData['productID'] as DocumentReference;
        final quantity = orderProductData['productQuantity'] as int;
        final price = (orderProductData['price'] as num).toDouble();

        // Get product details
        final productDoc = await productRef.get();
        if (productDoc.exists) {
          final productData = productDoc.data() as Map<String, dynamic>;
          final productName = productData['productName'] ?? 'Unknown Product';
          final productId = productDoc.id;

          productDetails.add({
            'id': productId,
            'name': productName,
            'quantity': quantity,
            'price': price,
          });
        }
      }

      _orderProducts[orderId] = productDetails;
    } catch (e) {
      print('Error fetching order products: $e');
      _orderProducts[orderId] = [];
    }
  }



  Future<void> _buildCustomerNamesMap() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        // Always use userId (similar to your OrderManagementController modification)
        _customerNames[userId] = userId;
      }
    } catch (e) {
      print('Error building customer names map: $e');
    }
  }

  // PDF Helper Methods
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
              style: pw.TextStyle(fontSize: 10,  color: PdfColors.grey600),
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
    final products = _orderProducts[order.id] ?? [];
    final totalQuantity = products.fold(0, (sum, product) => sum + (product['quantity'] as int));

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
            shortUserId(
                _customerNames[order.customerId] ?? order.customerId ?? 'N/A'
            ),
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        // MODIFIED: Product details column - shows each product
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: products.isEmpty
                ? [pw.Text('No products', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600))]
                : products.map((product) => pw.Padding(
              padding: pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                '${ProductStatusUtils.shortProductId(product['id'])} (${product['quantity']}x)',
                style: pw.TextStyle(fontSize: 7),
              ),
            )).toList(),
          ),
        ),
        pw.Container(
          padding: pw.EdgeInsets.all(5),
          child: pw.Text('$totalQuantity', style: pw.TextStyle(fontSize: 8)),
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