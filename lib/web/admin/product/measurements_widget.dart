// measurements_widget.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MeasurementsWidget extends StatelessWidget {
  final String? selectedCategoryId;
  final List<QueryDocumentSnapshot> categories;
  final TextEditingController bustController;
  final TextEditingController waistController;
  final TextEditingController hipController;
  final TextEditingController shoulderWidthController;
  final TextEditingController sleeveLengthController;
  final TextEditingController shirtLengthController;
  final TextEditingController inseamController;
  final TextEditingController outseamController;
  final TextEditingController totalLengthController;
  final Function(String) buildLabel;
  final Function(String) buildInputDecoration;

  const MeasurementsWidget({
    Key? key,
    required this.selectedCategoryId,
    required this.categories,
    required this.bustController,
    required this.waistController,
    required this.hipController,
    required this.shoulderWidthController,
    required this.sleeveLengthController,
    required this.shirtLengthController,
    required this.inseamController,
    required this.outseamController,
    required this.totalLengthController,
    required this.buildLabel,
    required this.buildInputDecoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Measurements (cm)'),
        const SizedBox(height: 10),
        _buildMeasurementsForCategory(),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildMeasurementsForCategory() {
    if (selectedCategoryId == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Please select a category to view measurements',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Get category name
    String categoryName = '';
    try {
      final categoryDoc = categories.firstWhere(
            (cat) => cat.id == selectedCategoryId,
      );
      final data = categoryDoc.data() as Map<String, dynamic>;
      categoryName = (data['catName'] ?? data['name'] ?? '').toLowerCase();
    } catch (e) {
      return _buildAllMeasurements();
    }

    // Return measurements based on category
    if (categoryName.contains('top') ||
        categoryName.contains('shirt') ||
        categoryName.contains('blouse') ||
        categoryName.contains('t-shirt') ||
        categoryName.contains('tshirt')) {
      return _buildTopMeasurements();
    } else if (categoryName.contains('bottom') ||
        categoryName.contains('pant') ||
        categoryName.contains('trouser') ||
        categoryName.contains('jean') ||
        categoryName.contains('short')) {
      return _buildBottomMeasurements();
    } else if (categoryName.contains('dress') ||
        categoryName.contains('gown') ||
        categoryName.contains('frock')) {
      return _buildDressMeasurements();
    } else {
      // Default to all measurements if category doesn't match
      return _buildAllMeasurements();
    }
  }

  Widget _buildTopMeasurements() {
    return Column(
      children: [
        // First row: Bust, Waist, Shoulder Width
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Bust'),
                  TextFormField(
                    controller: bustController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Waist'),
                  TextFormField(
                    controller: waistController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Shoulder Width'),
                  TextFormField(
                    controller: shoulderWidthController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Second row: Sleeve Length, Shirt Length
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Sleeve Length'),
                  TextFormField(
                    controller: sleeveLengthController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Shirt Length'),
                  TextFormField(
                    controller: shirtLengthController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(child: Container()), // Empty space for alignment
          ],
        ),
      ],
    );
  }

  Widget _buildBottomMeasurements() {
    return Column(
      children: [
        // First row: Waist, Hip
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Waist'),
                  TextFormField(
                    controller: waistController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Hip'),
                  TextFormField(
                    controller: hipController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(child: Container()), // Empty space for alignment
          ],
        ),
        const SizedBox(height: 15),
        // Second row: Inseam, Outseam
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Inseam'),
                  TextFormField(
                    controller: inseamController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Outseam'),
                  TextFormField(
                    controller: outseamController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(child: Container()), // Empty space for alignment
          ],
        ),
      ],
    );
  }

  Widget _buildDressMeasurements() {
    return Column(
      children: [
        // First row: Bust, Waist, Hip
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Bust'),
                  TextFormField(
                    controller: bustController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Waist'),
                  TextFormField(
                    controller: waistController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Hip'),
                  TextFormField(
                    controller: hipController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Second row: Total Length
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Total Length'),
                  TextFormField(
                    controller: totalLengthController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(child: Container()), // Empty space for alignment
            const SizedBox(width: 15),
            Expanded(child: Container()), // Empty space for alignment
          ],
        ),
      ],
    );
  }

  Widget _buildAllMeasurements() {
    return Column(
      children: [
        // First row of measurements
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Bust'),
                  TextFormField(
                    controller: bustController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Waist'),
                  TextFormField(
                    controller: waistController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Hip'),
                  TextFormField(
                    controller: hipController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Second row of measurements
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Shoulder Width'),
                  TextFormField(
                    controller: shoulderWidthController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Sleeve Length'),
                  TextFormField(
                    controller: sleeveLengthController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Shirt Length'),
                  TextFormField(
                    controller: shirtLengthController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Third row of measurements
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Inseam'),
                  TextFormField(
                    controller: inseamController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Outseam'),
                  TextFormField(
                    controller: outseamController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildLabel('Total Length'),
                  TextFormField(
                    controller: totalLengthController,
                    keyboardType: TextInputType.number,
                    decoration: buildInputDecoration('0.0'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}