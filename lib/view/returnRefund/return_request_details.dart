// view/return_request_details_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:secondsight/view/returnRefund/return_status.dart';
import '../../controller/returnRefund/return_request_details_controller.dart';
import '../../model/return_request_model.dart';
import '../../model/order_product_model.dart';
import '../../model/refund_model.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/progress_stepper.dart';
import '../widgets/return_status_utils.dart';
import 'cancel_return_request.dart';


class ReturnRequestDetailsView extends StatelessWidget {
  final String returnRequestId;
  final String userId;
  final ReturnRequestDetailsController controller = ReturnRequestDetailsController();

  ReturnRequestDetailsView({super.key, required this.returnRequestId, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: Text(
          'Return #${returnRequestId.substring(0, 6).toUpperCase()}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: controller.getReturnRequestStream(userId, returnRequestId),
        builder: (context, returnSnapshot) {
          if (!returnSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8E6CEF)));
          }
          if (returnSnapshot.data!.data() == null) {
            return const Center(child: Text('Return request not found'));
          }
          final returnRequest = ReturnRequestModel.fromDocument(returnSnapshot.data!);

          return FutureBuilder<DocumentSnapshot>(
            // Fix: Use the controller method with the correct parameters
            future: controller.getOrderProductDoc(
                returnRequest.userID,           // userId parameter
                returnRequest.orderID,          // orderID parameter
                returnRequest.orderProductID    // orderProductID parameter
            ),
            builder: (context, orderProductSnapshot) {
              if (!orderProductSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8E6CEF)));
              }

              // Add null check for orderProduct data
              final orderProductData = orderProductSnapshot.data!.data() as Map<String, dynamic>?;
              if (orderProductData == null) {
                return const Center(child: Text('Order product not found'));
              }

              final orderProduct = OrderProductModel.fromJson(orderProductData);
              return FutureBuilder<DocumentSnapshot?>(
                future: controller.getProductDoc(orderProduct.productID),
                builder: (context, productSnapshot) {
                  if (!productSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8E6CEF)));
                  }
                  final product = productSnapshot.data!.data() as Map<String, dynamic>?;
                  final productURL = (product?['productURL'] as List?)?.first?.toString() ?? '';
                  final productName = product?['productName'] ?? 'Unknown Product';

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusCard(returnRequest),

                        if (_getStatusFromRequest(returnRequest) != ReturnStatus.pending_approval)
                          ReturnStatusCard(status: _getStatusFromRequest(returnRequest)),

                        _buildProductCard(returnRequest),
                        _buildReturnDetails(returnRequest, orderProduct),

                        // Show refund details if refund document exists (refund processed)
                        StreamBuilder<QuerySnapshot>(
                          stream: controller.getRefundStream(userId, returnRequestId),
                          builder: (context, refundSnapshot) {
                            if (!refundSnapshot.hasData || refundSnapshot.data!.docs.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            final refundDoc = refundSnapshot.data!.docs.first;
                            final refundData = refundDoc.data() as Map<String, dynamic>;
                            final refund = RefundModel.fromJson(refundData);

                            return _buildRefundDetailsCardWithModel(refund);
                          },
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
        stream: controller.getReturnRequestStream(userId, returnRequestId),
        builder: (context, returnSnapshot) {
          if (!returnSnapshot.hasData) return const SizedBox.shrink();
          final returnRequest = ReturnRequestModel.fromDocument(returnSnapshot.data!);

          return _buildBottomBar(context, returnRequest);
        },
      ),
    );
  }

  ReturnStatus _getStatusFromRequest(ReturnRequestModel request) {
    // Convert your request status to ReturnStatus enum
    switch (request.returnStatus?.toLowerCase()) {
      case 'pending_approval':
        return ReturnStatus.pending_approval;
      case 'approved':
        return ReturnStatus.approved;
      case 'rejected':
        return ReturnStatus.rejected;
      case 'pending_inspection':
        return ReturnStatus.pending_inspection;
      case 'completed_inspection':
        return ReturnStatus.completed_inspection;
      case 'refunded':
        return ReturnStatus.refunded;
      case 'not_refunded':
        return ReturnStatus.not_refunded;
      case 'cancelled':
        return ReturnStatus.cancelled;
      case 'rejected':
        return ReturnStatus.rejected;
      default:
        return ReturnStatus.pending_approval;
    }
  }

  Widget _buildRefundDetailsCardWithModel(RefundModel refund) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
        border: Border.all(color: Colors.green.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.check_circle_outlined, color: Colors.green.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Refund Processed Successfully',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                    const SizedBox(height: 4),
                    Text('Your refund has been completed',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildRefundDetailRow('Refund Amount', 'RM ${refund.refundAmount.toStringAsFixed(2)}'),
                _buildRefundDetailRow('Refund Method', refund.refundMethod),
                _buildRefundDetailRow('Transaction ID', refund.transactionId),
                _buildRefundDetailRow('Processed Date', controller.formatDate(refund.refundDate)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    refund.refundMethod.toLowerCase().contains('wallet')
                        ? 'Refund has been credited to your wallet'
                        : 'Refund will appear in your original payment method within 3-5 business days',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRefundDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ReturnRequestModel request) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show rejection banner if status is rejected
          if (request.returnStatus.toLowerCase() == 'rejected') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Return Request Rejected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                        if (request.rejectReason != null && request.rejectReason!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            request.rejectReason!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else if (request.returnStatus.toLowerCase() == 'cancelled') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Return Request Cancelled',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Use the new timeline-style stepper
          ReturnStatusStepper(
            returnStatus: request.returnStatus,
            request: request,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ReturnRequestModel returnRequest) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.network(
                    returnRequest.productImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      returnRequest.productName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quantity: ${returnRequest.returnQuantity}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'RM ${returnRequest.returnPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildReturnDetails(ReturnRequestModel request, OrderProductModel orderProduct) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Return Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _buildDetailRow('Return Reason', request.returnReason),
          _buildDetailRow('Request ID', request.id.substring(0, 12).toUpperCase()),
          if (request.returnStatus.toLowerCase() == 'completed') ...[
            _buildDetailRow('Refund Amount', 'RM ${orderProduct.totalPrice.toStringAsFixed(2)}'),
            _buildDetailRow('Refund Method', 'Original Payment Method'),
          ],
          const SizedBox(height: 16),
          const Text('Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
            child: Text(
              request.returnComment?.isNotEmpty == true ? request.returnComment! : 'Return request for ${request.returnReason.toLowerCase()}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          request.returnImages.isNotEmpty
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Uploaded Images',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: request.returnImages.length,
                  itemBuilder: (context, index) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.network(
                        request.returnImages[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
              : const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'No image uploaded',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ReturnRequestModel request) {
    return StreamBuilder<QuerySnapshot>(
      stream: controller.getRefundStream(userId, returnRequestId),
      builder: (context, refundSnapshot) {
        // Hide bottom bar if refund document exists (refund processed)
        if (refundSnapshot.hasData && refundSnapshot.data!.docs.isNotEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  if (request.returnStatus.toLowerCase() == 'submitted' || request.returnStatus.toLowerCase() == 'pending')
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => showCancelDialog(context, userId, request),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.redAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.redAccent, width: 1.5),
                            ),
                          ),
                          child: const Text('Cancel Request', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  if (request.returnStatus.toLowerCase() == 'submitted' || request.returnStatus.toLowerCase() == 'pending')
                    const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Opening chat support...'),
                              backgroundColor: Color(0xFF8E6CEF),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8E6CEF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Contact Support', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Flexible(
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}