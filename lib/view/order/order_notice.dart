// order_status_notice.dart
import 'package:flutter/material.dart';

enum OrderNoticeType {
  cancelled,
  pendingPayment,
}

class OrderStatusNotice extends StatelessWidget {
  final OrderNoticeType type;
  final VoidCallback? onPaymentPressed;
  final String? customMessage;

  const OrderStatusNotice({
    super.key,
    required this.type,
    this.onPaymentPressed,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case OrderNoticeType.cancelled:
        return _buildCancelledNotice();
      case OrderNoticeType.pendingPayment:
        return _buildPendingPaymentNotice();
    }
  }

  Widget _buildCancelledNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red[200]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cancel_outlined,
            color: Colors.red[600],
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Order Cancelled',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            customMessage ?? 'This order has been cancelled and will not be processed.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.red[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPaymentNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange[200]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.payment_outlined,
            color: Colors.orange[600],
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Payment Required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.orange[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            customMessage ?? 'Please complete your payment to proceed with this order.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (onPaymentPressed != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPaymentPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Complete Payment',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}