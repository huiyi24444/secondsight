import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'monthly_sales_report.dart';
import 'daily_sales_report.dart';
import 'monthly_return_report.dart';

class AdminReportPage extends StatefulWidget {
  @override
  _AdminReportPageState createState() => _AdminReportPageState();
}

class _AdminReportPageState extends State<AdminReportPage> {
  DateTime selectedMonth = DateTime.now();
  DateTime selectedDate = DateTime.now();
  bool isGenerating = false;

  // Report instances
  final _monthlySalesReport = MonthlySalesReport();
  final _dailySalesReport = DailySalesReport();
  final _monthlyReturnReport = MonthlyReturnReport();

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

  // Report generation methods that delegate to separate classes
  Future<void> _generateMonthlySalesReport() async {
    await _monthlySalesReport.generateMonthlySalesReport(
      context,
      selectedMonth,
          (isGenerating) => setState(() => this.isGenerating = isGenerating),
    );
  }

  Future<void> _generateDailySalesReport() async {
    await _dailySalesReport.generateDailySalesReport(
      context,
      selectedDate,
          (isGenerating) => setState(() => this.isGenerating = isGenerating),
    );
  }

  Future<void> _generateMonthlyReturnReport() async {
    await _monthlyReturnReport.generateMonthlyReturnReport(
      context,
      selectedMonth,
          (isGenerating) => setState(() => this.isGenerating = isGenerating),
    );
  }
}