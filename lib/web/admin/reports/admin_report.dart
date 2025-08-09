import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../widget/topbar.dart';
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
  String? selectedReportType;

  // Report instances
  final _monthlySalesReport = MonthlySalesReport();
  final _dailySalesReport = DailySalesReport();
  final _monthlyReturnReport = MonthlyReturnReport();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Main Content
          Expanded(
            child: Column(
              children: [
                const CustomTopBar(
                  title: 'Report',
                ),
                // Header
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          SingleChildScrollView(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Report Type Selection
                                Container(
                                  padding: EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Select Report Type',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2C3E50),
                                        ),
                                      ),
                                      SizedBox(height: 20),

                                      // Report Options
                                      _buildReportOption(
                                        id: 'monthly_sales',
                                        title: 'Monthly Sales Summary Report',
                                        subtitle: 'Comprehensive overview of monthly sales performance',
                                        icon: Icons.trending_up_outlined,
                                        color: Color(0xFF3498DB),
                                      ),

                                      _buildReportOption(
                                        id: 'daily_sales',
                                        title: 'Daily Sales Summary Report',
                                        subtitle: 'Detailed breakdown of daily transactions',
                                        icon: Icons.receipt_outlined,
                                        color: Color(0xFF27AE60),
                                      ),

                                      _buildReportOption(
                                        id: 'monthly_returns',
                                        title: 'Monthly Return Request Report',
                                        subtitle: 'Analysis of return requests and reasons',
                                        icon: Icons.assignment_return_outlined,
                                        color: Color(0xFFE67E22),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 24),

                                // Report Configuration
                                if (selectedReportType != null)
                                  Container(
                                    padding: EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Report Configuration',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                        SizedBox(height: 20),

                                        // Date Selection
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    selectedReportType == 'daily_sales'
                                                        ? 'Select Date'
                                                        : 'Select Month',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                  SizedBox(height: 8),
                                                  InkWell(
                                                    onTap: () => selectedReportType == 'daily_sales'
                                                        ? _selectDate(context)
                                                        : _selectMonth(context),
                                                    child: Container(
                                                      padding: EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 12,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color: Colors.grey[300]!,
                                                        ),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            selectedReportType == 'daily_sales'
                                                                ? DateFormat('dd MMMM yyyy').format(selectedDate)
                                                                : DateFormat('MMMM yyyy').format(selectedMonth),
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              color: Color(0xFF2C3E50),
                                                            ),
                                                          ),
                                                          Icon(
                                                            Icons.calendar_today_outlined,
                                                            size: 20,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: 24),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Format',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                  SizedBox(height: 8),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color: Colors.grey[300]!,
                                                      ),
                                                      borderRadius: BorderRadius.circular(4),
                                                      color: Colors.grey[50],
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.picture_as_pdf,
                                                          size: 20,
                                                          color: Colors.red[700],
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'PDF Document',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            color: Color(0xFF2C3E50),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        SizedBox(height: 32),

                                        // Generate Button
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  selectedReportType = null;
                                                });
                                              },
                                              child: Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 24,
                                                  vertical: 12,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 16),
                                            ElevatedButton.icon(
                                              onPressed: isGenerating ? null : _generateReport,
                                              icon: isGenerating
                                                  ? SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                                  : Icon(
                                                Icons.download_outlined,
                                                color: Colors.white,
                                              ),
                                              label: Text(
                                                isGenerating ? 'Generating...' : 'Generate Report',
                                                style: TextStyle(fontSize: 16,  color: Colors.white,),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Color(0xFF8E6CEF),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 24,
                                                  vertical: 12,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildReportOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = selectedReportType == id;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            selectedReportType = id;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? color.withOpacity(0.05) : Colors.white,
          ),
          child: Row(
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
                  size: 24,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Radio<String>(
                value: id,
                groupValue: selectedReportType,
                onChanged: (value) {
                  setState(() {
                    selectedReportType = value;
                  });
                },
                activeColor: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectMonth(BuildContext context) async {
    final picked = await showMonthPicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

  Future<void> _generateReport() async {
    switch (selectedReportType) {
      case 'monthly_sales':
        await _generateMonthlySalesReport();
        break;
      case 'daily_sales':
        await _generateDailySalesReport();
        break;
      case 'monthly_returns':
        await _generateMonthlyReturnReport();
        break;
    }
  }

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