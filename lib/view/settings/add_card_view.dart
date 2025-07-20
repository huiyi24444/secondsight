// add_card_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controller/settings/add_card_controller.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/long_button.dart';

class AddCardView extends StatelessWidget {
  final String userId;

  const AddCardView({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AddCardController>(
      create: (_) => AddCardController(userId: userId),
      child: const _AddCardForm(),
    );
  }
}

class _AddCardForm extends StatelessWidget {
  const _AddCardForm();

  @override
  Widget build(BuildContext context) {
    return Consumer<AddCardController>(
      builder: (context, controller, child) {
        return Scaffold(
          appBar: AppBar(
            leading: const CustomBackButton(),
            title: const Text("Add Payment Card"),
            backgroundColor: Colors.transparent,
            centerTitle: true,
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Information card about Stripe security
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.security_outlined,
                            color: Colors.blue[700],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Secure Payment Setup',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your payment information will be securely processed and stored by Stripe. We never store your actual card details on our servers.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[600],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // Set as default checkbox
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: controller.isDefault,
                        onChanged: controller.updateDefault,
                        activeColor: const Color(0xFF8E6CEF),
                      ),
                      const Expanded(
                        child: Text(
                          "Set as default payment card",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Information about the process
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You\'ll be redirected to a secure payment form to enter your card details. No charges will be made at this time.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[700],
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Add payment method button
                LongButton(
                  label: controller.isLoading ? "Processing..." : "Add Payment Card",
                  onPressed: controller.isLoading
                      ? null
                      : () => controller.saveCard(context),
                ),

                const SizedBox(height: 16),

                // Test mode notice (remove in production)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        color: Colors.amber[700],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Test Mode: Use card 4242 4242 4242 4242 with any future date and CVC',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}