// cancel_order_dialog_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controller/order/cancel_dialog_controller.dart';

class CancelOrderDialog extends StatefulWidget {
  final String orderId;
  final VoidCallback? onCancel;
  final Function(String reason, String? note)? onConfirm;

  const CancelOrderDialog({
    super.key,
    required this.orderId,
    this.onCancel,
    this.onConfirm,
  });

  @override
  State<CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<CancelOrderDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Animation<double>? _slideAnimation;
  Animation<double>? _fadeAnimation;
  late CancelOrderDialogController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CancelOrderDialogController();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.3,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController?.forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CancelOrderDialogController>.value(
      value: _controller,
      child: AnimatedBuilder(
        animation: _animationController ?? AnimationController(duration: Duration.zero, vsync: this),
        builder: (context, child) {
          // Safe access with null checks and defaults
          final fadeValue = _fadeAnimation?.value ?? 1.0;
          final slideValue = _slideAnimation?.value ?? 0.0;

          return Material(
            type: MaterialType.transparency,
            child: Container(
              color: Colors.black.withOpacity(0.6 * fadeValue),
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, MediaQuery.of(context).size.height * slideValue),
                  child: Opacity(
                    opacity: fadeValue,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.85,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(),
                          SizedBox(height:15),
                          Flexible(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: _buildContent(),
                            ),
                          ),
                          _buildActions(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.withOpacity(0.1),
            Colors.red.withOpacity(0.05),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.cancel_outlined,
              color: Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cancel Order',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Order #${widget.orderId}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Consumer<CancelOrderDialogController>(
      builder: (context, controller, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'We\'re sorry to see you cancel your order. Your feedback helps us improve. Please select a reason:',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),

              // Cancellation reasons with modern cards
              ...controller.cancellationReasons.map((reason) =>
                  _buildReasonCard(reason, controller)),

              // Custom reason input
              if (controller.showCustomReasonField) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: TextField(
                    controller: controller.customReasonController,
                    maxLines: 3,
                    onChanged: (_) => controller.notifyListeners(),
                    decoration: const InputDecoration(
                      hintText: 'Please tell us more about your reason...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      hintStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Modern warning card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.amber.withOpacity(0.1),
                      Colors.orange.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Important Notice',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'This action cannot be undone. Refunds will be processed within 3-5 business days.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[700],
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReasonCard(String reason, CancelOrderDialogController controller) {
    final isSelected = controller.selectedReason == reason;

    return GestureDetector(
      onTap: () => controller.setSelectedReason(reason),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8E6CEF).withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF8E6CEF) : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF8E6CEF).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF8E6CEF) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFF8E6CEF) : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                Icons.check,
                size: 14,
                color: Colors.white,
              )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                reason,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF8E6CEF) : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Consumer<CancelOrderDialogController>(
      builder: (context, controller, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              // Modern action buttons
              Row(
                children: [
                  // Keep Order Button
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextButton(
                        onPressed: controller.isProcessing
                            ? null
                            : () {
                          _animationController?.reverse().then((_) {
                            Navigator.of(context).pop();
                            widget.onCancel?.call();
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Keep Order',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Cancel Order Button
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: controller.canProceed && !controller.isProcessing
                            ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.red, Colors.red.shade600],
                        )
                            : null,
                        color: controller.canProceed && !controller.isProcessing
                            ? null
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: controller.canProceed && !controller.isProcessing
                            ? [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                            : [],
                      ),
                      child: ElevatedButton(
                        onPressed: (controller.canProceed && !controller.isProcessing)
                            ? () => _handleCancelOrder(controller)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: controller.isProcessing
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Text(
                          'Cancel Order',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleCancelOrder(CancelOrderDialogController controller) async {
    await controller.processCancellation(
      onConfirm: widget.onConfirm ?? (_, __) {},
      onComplete: () {
        if (mounted) {
          _animationController?.reverse().then((_) {
            Navigator.of(context).pop();
          });
        }
      },
    );
  }
}

// Helper function to show the dialog
Future<void> showCancelOrderDialog({
  required BuildContext context,
  required String orderId,
  VoidCallback? onCancel,
  Function(String reason, String? note)? onConfirm,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent, // Custom background handled in widget
    builder: (BuildContext context) {
      return CancelOrderDialog(
        orderId: orderId,
        onCancel: onCancel,
        onConfirm: onConfirm,
      );
    },
  );
}