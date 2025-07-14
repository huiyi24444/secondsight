import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            child: Form(
              key: controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Number Field
                  _buildLabel("Card Number"),
                  TextFormField(
                    controller: controller.cardNumberController,
                    decoration: InputDecoration(
                      hintText: "1234 5678 9012 3456",
                      hintStyle: TextStyle(
                        color: Color(0xFF7C7D7C), // 👈 lighter hint text color
                      ),
                      prefixIcon: const Icon(Icons.credit_card_outlined),
                      suffixIcon: controller.detectedBrand.isNotEmpty
                          ? _buildCardBrandIcon(controller.detectedBrand)
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CardNumberFormatter(),
                    ],
                    onChanged: controller.onCardNumberChanged,
                    validator: controller.validateCardNumber,
                  ),
                  const SizedBox(height: 20),

                  // Card Holder Name
                  _buildLabel("Cardholder Name"),
                  TextFormField(
                    controller: controller.cardHolderNameController,
                    decoration: const InputDecoration(
                      hintText: "John Doe",
                      hintStyle: TextStyle(
                        color: Color(0xFF7C7D7C), // 👈 lighter hint text color
                      ),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),

                  // Expiry Date and CVV Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Expiry Date"),
                            TextFormField(
                              controller: controller.expiryDateController,
                              decoration: const InputDecoration(
                                hintText: "MM/YY",
                                hintStyle: TextStyle(
                                  color: Color(0xFF7C7D7C), // 👈 lighter hint text color
                                ),
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                ExpiryDateFormatter(),
                              ],
                              validator: controller.validateExpiryDate,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("CVV"),
                            TextFormField(
                              controller: controller.cvvController,
                              decoration: InputDecoration(
                                hintText: "123",
                                hintStyle: TextStyle(
                                  color: Color(0xFF7C7D7C), // 👈 lighter hint text color
                                ),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.info_outline, size: 20),
                                  onPressed: () => _showCVVInfo(context),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              obscureText: true,
                              validator: controller.validateCVV,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Set as default checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: controller.isDefault,
                        onChanged: controller.updateDefault,
                        activeColor: const Color(0xFF8E6CEF),
                      ),
                      const Text("Set as default payment method"),
                    ],
                  ),

                  const Spacer(),

                  // Security notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.security_outlined,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your card information is encrypted and secure',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Save button
                  LongButton(
                    label: "Add Card",
                    onPressed: controller.isLoading
                        ? null
                        : () => controller.saveCard(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    ),
  );

  Widget _buildCardBrandIcon(String brand) {
    IconData iconData;
    Color iconColor;

    switch (brand.toLowerCase()) {
      case 'visa':
        iconData = Icons.credit_card;
        iconColor = const Color(0xFF2663D4);
        break;
      case 'mastercard':
        iconData = Icons.credit_card;
        iconColor = const Color(0xFFEB001B);
        break;
      default:
        iconData = Icons.credit_card;
        iconColor = Colors.grey;
    }

    return Icon(
      iconData,
      color: iconColor,
      size: 24,
    );
  }

  void _showCVVInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What is CVV?'),
        content: const Text(
          'CVV (Card Verification Value) is a 3 or 4-digit security code on your card.\n\n'
              '• For Visa, Mastercard, and Discover: 3 digits on the back\n'
              '• For American Express: 4 digits on the front',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// Custom formatter for card number (adds spaces every 4 digits)
class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i % 4 == 0 && i != 0) buffer.write(' ');
      buffer.write(text[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

// Custom formatter for expiry date (MM/YY format)
class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length && i < 4; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}