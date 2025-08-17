import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controller/settings/add_address_controller.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/long_button.dart';

class AddAddressView extends StatelessWidget {
  final String userId;

  const AddAddressView({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AddAddressController>(
      create: (_) => AddAddressController(userId: userId),
      child: const _AddAddressForm(),
    );
  }
}

class _AddAddressForm extends StatelessWidget {
  const _AddAddressForm();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<AddAddressController>(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text("Add address"),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel("Full Name"),
                TextFormField(
                  controller: controller.fullNameController,
                  decoration: const InputDecoration(
                    hintText: "Full Name",
                    hintStyle: TextStyle(
                      color: Color(0xFF7C7D7C),
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _buildLabel("Phone Number"),
                TextFormField(
                  controller: controller.phoneNumController,
                  decoration: const InputDecoration(
                    hintText: '60123456789',
                    hintStyle: TextStyle(
                      color: Color(0xFF7C7D7C),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: controller.validatePhoneNumber,
                  onChanged: (value) {
                    // Optional: Auto-format or clean input while typing
                    // This is just an example - you might want to implement more sophisticated formatting
                  },
                ),
                const SizedBox(height: 25),
                _buildLabel("Address Line 1"),
                TextFormField(
                  controller: controller.streetOneController,
                  decoration: const InputDecoration(
                    hintText: "Address Line 1",
                    hintStyle: TextStyle(
                      color: Color(0xFF7C7D7C),
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _buildLabel("Address Line 2"),
                TextFormField(
                  controller: controller.streetTwoController,
                  decoration: const InputDecoration(
                    hintText: "Address Line 2",
                    hintStyle: TextStyle(
                      color: Color(0xFF7C7D7C),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildLabel("City"),
                TextFormField(
                  controller: controller.cityController,
                  decoration: const InputDecoration(
                    hintText: "City",
                    hintStyle: TextStyle(
                      color: Color(0xFF7C7D7C),
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("State"),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: controller.selectedState,
                            decoration: const InputDecoration(
                              hintText: "State",
                              hintStyle: TextStyle(
                                color: Color(0xFF7C7D7C),
                              ),
                            ),
                            items: controller.malaysianStates
                                .map((state) => DropdownMenuItem(
                              value: state,
                              child: Text(state),
                            ))
                                .toList(),
                            onChanged: controller.updateSelectedState,
                            validator: (value) =>
                            value == null ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Zip Code"),
                          TextFormField(
                            controller: controller.zipCodeController,
                            decoration: const InputDecoration(
                              hintText: "Zip Code",
                              hintStyle: TextStyle(
                                color: Color(0xFF7C7D7C),
                              ),
                            ),
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
                      onChanged: controller.updateDefault,
                    ),
                    const Text("Set as default address"),
                  ],
                ),
                const SizedBox(height: 30),
                LongButton(
                  label: "Save",
                  onPressed: () => controller.saveAddress(context),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
  );
}