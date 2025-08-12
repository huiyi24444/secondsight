import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secondsight/view/widgets/custom_back_button.dart';
import 'package:secondsight/view/widgets/long_button.dart';
import '../../controller/settings/edit_address_controller.dart';

class EditAddressView extends StatefulWidget {
  final String userId;
  final String addressId;
  final Map<String, dynamic> initialData;

  const EditAddressView({
    super.key,
    required this.userId,
    required this.addressId,
    required this.initialData,
  });

  @override
  State<EditAddressView> createState() => _EditAddressViewState();
}

class _EditAddressViewState extends State<EditAddressView> {
  late EditAddressController controller;

  @override
  void initState() {
    super.initState();
    controller = EditAddressController(
      userId: widget.userId,
      addressId: widget.addressId,
      initialData: widget.initialData,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text("Edit address"),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      // Add resizeToAvoidBottomInset to handle keyboard properly
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Full Name",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: controller.fullName,
                decoration: const InputDecoration(hintText: "Full Name"),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              const Text("Phone Number (+60)",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: controller.phoneNum,
                decoration: const InputDecoration(
                  hintText: "Phone Number (e.g. 60123456789)",
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  PhoneNumberInputFormatter(),
                  LengthLimitingTextInputFormatter(11),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Required';
                  }
                  if (v.length < 10) {
                    return 'Phone number must be at least 10 digits';
                  }
                  if (!v.startsWith('6')) {
                    return 'Phone number must start with 6';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 25),

              const Text("Street Address",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: controller.streetOne,
                decoration: const InputDecoration(hintText: "Street Address"),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              const Text("Address Line 2",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: controller.streetTwo,
                decoration: const InputDecoration(hintText: "Address Line 2"),
              ),
              const SizedBox(height: 12),

              const Text("City",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: controller.city,
                decoration: const InputDecoration(hintText: "City"),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("State", style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                        TextFormField(
                          controller: controller.state,
                          decoration: const InputDecoration(hintText: "State"),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Zip Code", style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                        TextFormField(
                          controller: controller.zipCode,
                          decoration: const InputDecoration(
                              hintText: "Zip Code"),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: controller.isDefault,
                    onChanged: (value) {
                      setState(() {
                        controller.isDefault = value ?? false;
                      });
                    },
                  ),
                  const Text("Set as default address"),
                ],
              ),
              // Replace Spacer with SizedBox since we're now in a scrollable view
              const SizedBox(height: 32),
              LongButton(
                label: "Save",
                onPressed: () => controller.updateAddress(context),
              ),
              // Add bottom padding to ensure button is accessible above keyboard
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class PhoneNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // Remove any non-digit characters
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Limit to 11 digits
    if (digitsOnly.length > 11) {
      digitsOnly = digitsOnly.substring(0, 11);
    }

    // If there are digits and first digit is not 6, replace it with 6
    if (digitsOnly.isNotEmpty && !digitsOnly.startsWith('6')) {
      digitsOnly = '6${digitsOnly.substring(1)}';
    }

    // If user tries to type something but field is empty, start with 6
    if (digitsOnly.isEmpty && newValue.text.isNotEmpty) {
      digitsOnly = '6';
    }

    return TextEditingValue(
      text: digitsOnly,
      selection: TextSelection.collapsed(offset: digitsOnly.length),
    );
  }
}