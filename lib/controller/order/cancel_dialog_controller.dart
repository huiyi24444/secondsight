// cancel_order_dialog_controller.dart

import 'package:flutter/material.dart';

class CancelOrderDialogController extends ChangeNotifier {
  // State variables
  String? _selectedReason;
  final TextEditingController customReasonController = TextEditingController();
  bool _isProcessing = false;

  // Cancellation reasons
  final List<String> cancellationReasons = [
    'Changed my mind',
    'Found a better price elsewhere',
    'Product no longer needed',
    'Other (please specify)',
  ];

  // Getters
  String? get selectedReason => _selectedReason;
  bool get isProcessing => _isProcessing;
  bool get showCustomReasonField => _selectedReason == 'Other (please specify)';

  // Check if can proceed
  bool get canProceed {
    return _selectedReason != null &&
        (_selectedReason != 'Other (please specify)' ||
            customReasonController.text.trim().isNotEmpty);
  }

  // Set selected reason
  void setSelectedReason(String reason) {
    _selectedReason = reason;
    notifyListeners();
  }

  // Set processing state
  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  // Get final cancellation data
  Map<String, String?> getCancellationData() {
    String finalReason = _selectedReason!;
    String? note;

    if (_selectedReason == 'Other (please specify)') {
      // Use the custom reason as the main reason
      finalReason = customReasonController.text.trim();
    } else {
      // Use selected reason and add any custom text as a note
      if (customReasonController.text.trim().isNotEmpty) {
        note = customReasonController.text.trim();
      }
    }

    return {
      'reason': finalReason,
      'note': note,
    };
  }

  // Process cancellation
  Future<void> processCancellation({
    required Function(String reason, String? note) onConfirm,
    required VoidCallback onComplete,
  }) async {
    setProcessing(true);

    // Get cancellation data
    final data = getCancellationData();

    // Small delay to show processing state
    await Future.delayed(const Duration(milliseconds: 500));

    // Call the onConfirm callback
    onConfirm(data['reason']!, data['note']);

    // Call completion callback
    onComplete();
  }

  @override
  void dispose() {
    customReasonController.dispose();
    super.dispose();
  }
}