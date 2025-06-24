import 'package:flutter/material.dart';

class PriceRangeSelector extends StatefulWidget {
  final double min;
  final double max;
  final Function(double, double) onChanged;

  const PriceRangeSelector({
    super.key,
    this.min = 1,
    this.max = 500,
    required this.onChanged,
  });

  @override
  State<PriceRangeSelector> createState() => _PriceRangeSelectorState();
}

class _PriceRangeSelectorState extends State<PriceRangeSelector> {
  RangeValues _currentRange = const RangeValues(30, 100); // Initial values

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Range (RM)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Min: RM${_currentRange.start.round()}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Max: RM${_currentRange.end.round()}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        RangeSlider(
          values: _currentRange,
          min: widget.min,
          max: widget.max,
          divisions: 100,

          onChanged: (RangeValues values) {
            setState(() {
              _currentRange = values;
            });
            widget.onChanged(values.start, values.end); // Callback to parent
          },
        ),
      ],
    );
  }
}
