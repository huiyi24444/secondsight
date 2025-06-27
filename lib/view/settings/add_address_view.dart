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
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text("Add address"),
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
              _buildLabel("Full Name"),
              TextFormField(
                controller: controller.fullNameController,
                decoration: const InputDecoration(hintText: "Full Name"),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildLabel("Phone Number"),
              TextFormField(
                controller: controller.phoneNumController,
                decoration: const InputDecoration(hintText: "Phone Number"),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 25),
              _buildLabel("Address Line 1"),
              TextFormField(
                controller: controller.streetOneController,
                decoration: const InputDecoration(hintText: "Address Line 1"),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildLabel("Address Line 2"),
              TextFormField(
                controller: controller.streetTwoController,
                decoration: const InputDecoration(hintText: "Address Line 2"),
              ),
              const SizedBox(height: 12),
              _buildLabel("City"),
              TextFormField(
                controller: controller.cityController,
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
                        _buildLabel("State"),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: controller.selectedState,
                          decoration: const InputDecoration(hintText: "State"),
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
                          decoration:
                          const InputDecoration(hintText: "Zip Code"),
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
              const Spacer(),
              LongButton(
                label: "Save",
                onPressed: () => controller.saveAddress(context),
              ),
            ],
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
