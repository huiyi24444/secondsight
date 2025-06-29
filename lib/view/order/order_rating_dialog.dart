import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controller/order/order_details_controller.dart';
import '../../model/order_model.dart';

void showRatingDialog({
  required BuildContext context,
  required OrdersModel order,
}) {
  final controller = Provider.of<OrderDetailsController>(context, listen: false);

  controller.resetRatingState();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Consumer<OrderDetailsController>(
        builder: (context, controller, child) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Rate Your Order',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'How was your experience with this order?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () => controller.updateRating(index + 1),
                      child: Icon(
                        index < controller.rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller.reviewController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Share your experience (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF8E6CEF)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: controller.isRatingValid()
                    ? () async {
                  Navigator.of(context).pop();
                  final success = await controller.submitRating();
                  final messenger = ScaffoldMessenger.of(context);

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? controller.getRatingSuccessMessage()
                            : 'Failed to submit rating.',
                      ),
                      backgroundColor:
                      success ? const Color(0xFF8E6CEF) : Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E6CEF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Submit',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
