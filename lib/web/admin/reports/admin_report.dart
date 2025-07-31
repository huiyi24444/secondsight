import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';

class AdminReportPage extends StatefulWidget {
  @override
  _AdminReportPageState createState() => _AdminReportPageState();
}

class _AdminReportPageState extends State<AdminReportPage> {
  DateTime selectedMonth = DateTime.now();
  DateTime selectedDate = DateTime.now();
  bool isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Admin Report Generation'),
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

            // Report Cards
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

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildPdfHeader('Monthly Sales Summary Report',
              DateFormat('MMMM yyyy').format(selectedMonth)),
          pw.SizedBox(height: 20),

          // Key Metrics
          pw.Container(
            padding: pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildMetricBox('Total Sales', '\$45,678', PdfColors.blue),
                _buildMetricBox('Total Orders', '342', PdfColors.green),
                _buildMetricBox('Avg Order Value', '\$133.56', PdfColors.orange),
                _buildMetricBox('Growth', '+15.3%', PdfColors.purple),
              ],
            ),
          ),

          pw.SizedBox(height: 30),

          // Sales by Category
          pw.Text(
            'Sales by Category',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Category', isHeader: true),
                  _buildTableCell('Units Sold', isHeader: true),
                  _buildTableCell('Revenue', isHeader: true),
                  _buildTableCell('% of Total', isHeader: true),
                ],
              ),
              _buildTableRow(['Jackets', '89', '\$12,460', '27.3%']),
              _buildTableRow(['Dresses', '124', '\$9,920', '21.7%']),
              _buildTableRow(['Shirts', '156', '\$7,800', '17.1%']),
              _buildTableRow(['Pants', '98', '\$6,860', '15.0%']),
              _buildTableRow(['Accessories', '234', '\$4,680', '10.2%']),
              _buildTableRow(['Others', '87', '\$3,958', '8.7%']),
            ],
          ),

          pw.SizedBox(height: 30),

          // Monthly Trend
          pw.Text(
            'Sales Trend',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            height: 200,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Center(
              child: pw.Text('[Sales trend chart would be displayed here]'),
            ),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'monthly_sales_report_${DateFormat('yyyy_MM').format(selectedMonth)}.pdf',
    );

    setState(() => isGenerating = false);
  }

  Future<void> _generateDailySalesReport() async {
    setState(() => isGenerating = true);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildPdfHeader('Daily Sales Report',
              DateFormat('dd MMMM yyyy').format(selectedDate)),
          pw.SizedBox(height: 20),

          // Summary
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Total Orders', '28'),
              _buildSummaryItem('Total Revenue', '\$3,752'),
              _buildSummaryItem('Avg Order Value', '\$134'),
            ],
          ),

          pw.SizedBox(height: 30),

          // Transactions Table
          pw.Text(
            'Transaction Details',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: pw.FixedColumnWidth(80),
              1: pw.FixedColumnWidth(100),
              2: pw.FixedColumnWidth(80),
              3: pw.FlexColumnWidth(),
              4: pw.FixedColumnWidth(40),
              5: pw.FixedColumnWidth(60),
              6: pw.FixedColumnWidth(60),
              7: pw.FixedColumnWidth(70),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Order ID', isHeader: true, fontSize: 10),
                  _buildTableCell('Date & Time', isHeader: true, fontSize: 10),
                  _buildTableCell('Username', isHeader: true, fontSize: 10),
                  _buildTableCell('Product', isHeader: true, fontSize: 10),
                  _buildTableCell('Qty', isHeader: true, fontSize: 10),
                  _buildTableCell('Price', isHeader: true, fontSize: 10),
                  _buildTableCell('Total', isHeader: true, fontSize: 10),
                  _buildTableCell('Status', isHeader: true, fontSize: 10),
                ],
              ),
              _buildDetailedTableRow(['ORD-2024001', '09:15 AM', 'john_doe', 'Vintage Denim Jacket', '1', '\$89', '\$89', 'Completed']),
              _buildDetailedTableRow(['ORD-2024002', '10:30 AM', 'sarah_m', 'Floral Summer Dress', '2', '\$65', '\$130', 'Completed']),
              _buildDetailedTableRow(['ORD-2024003', '11:45 AM', 'mike_wilson', 'Classic Leather Boots', '1', '\$120', '\$120', 'Pending']),
              _buildDetailedTableRow(['ORD-2024004', '01:20 PM', 'emma_j', 'Retro Band T-Shirt', '3', '\$25', '\$75', 'Completed']),
              _buildDetailedTableRow(['ORD-2024005', '02:15 PM', 'alex_chen', 'Wool Winter Coat', '1', '\$150', '\$150', 'Completed']),
            ],
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'daily_sales_report_${DateFormat('yyyy_MM_dd').format(selectedDate)}.pdf',
    );

    setState(() => isGenerating = false);
  }

  Future<void> _generateMonthlyReturnReport() async {
    setState(() => isGenerating = true);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildPdfHeader('Monthly Return Request Report',
              DateFormat('MMMM yyyy').format(selectedMonth)),
          pw.SizedBox(height: 20),

          // Key Metrics
          pw.Container(
            padding: pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildMetricBox('Total Returns', '47', PdfColors.red),
                _buildMetricBox('Return Value', '\$3,245', PdfColors.orange),
                _buildMetricBox('Return Rate', '13.7%', PdfColors.blue),
                _buildMetricBox('Top Reason', 'Size Issue', PdfColors.purple),
              ],
            ),
          ),

          pw.SizedBox(height: 30),

          // Return Analysis by Reason
          pw.Text(
            'Return Analysis by Reason',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Return Reason', isHeader: true),
                  _buildTableCell('Count', isHeader: true),
                  _buildTableCell('Percentage', isHeader: true),
                  _buildTableCell('Total Value', isHeader: true),
                ],
              ),
              _buildTableRow(['Size Issues', '18', '38.3%', '\$1,242']),
              _buildTableRow(['Quality Concerns', '12', '25.5%', '\$828']),
              _buildTableRow(['Not as Described', '8', '17.0%', '\$552']),
              _buildTableRow(['Changed Mind', '5', '10.6%', '\$345']),
              _buildTableRow(['Damaged in Transit', '3', '6.4%', '\$207']),
              _buildTableRow(['Other', '1', '2.1%', '\$71']),
            ],
          ),

          pw.SizedBox(height: 30),

          // Return Request Status Breakdown
          pw.Text(
            'Return Request Status Breakdown',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Status', isHeader: true),
                  _buildTableCell('Count', isHeader: true),
                  _buildTableCell('Percentage', isHeader: true),
                ],
              ),
              _buildTableRow(['Approved', '35', '74.5%']),
              _buildTableRow(['Pending Review', '8', '17.0%']),
              _buildTableRow(['Rejected', '4', '8.5%']),
            ],
          ),

          pw.SizedBox(height: 30),

          // Recommendations
          pw.Container(
            padding: pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Recommendations',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('• Improve size charts and product descriptions to reduce size-related returns'),
                pw.Text('• Implement quality control checks to address quality concerns'),
                pw.Text('• Enhance product photography to better represent items'),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'monthly_return_report_${DateFormat('yyyy_MM').format(selectedMonth)}.pdf',
    );

    setState(() => isGenerating = false);
  }

  // PDF Helper Methods
  pw.Widget _buildPdfHeader(String title, String date) {
    return pw.Container(
      padding: pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated on: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            'Report Period: $date',
            style: pw.TextStyle(
              fontSize: 14,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMetricBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
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
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false, double fontSize = 12}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.TableRow _buildTableRow(List<String> cells) {
    return pw.TableRow(
      children: cells.map((cell) => _buildTableCell(cell)).toList(),
    );
  }

  pw.TableRow _buildDetailedTableRow(List<String> cells) {
    return pw.TableRow(
      children: cells.map((cell) => _buildTableCell(cell, fontSize: 9)).toList(),
    );
  }
}