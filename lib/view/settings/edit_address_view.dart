import 'package:flutter/material.dart';
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Full Name", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: controller.fullName,
                decoration: const InputDecoration(hintText: "Full Name"),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              const Text("Phone Number", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: controller.phoneNum,
                decoration: const InputDecoration(hintText: "Phone Number"),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 25),

              const Text("Street Address", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: controller.streetOne,
                decoration: const InputDecoration(hintText: "Street Address"),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              const Text("Address Line 2", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: controller.streetTwo,
                decoration: const InputDecoration(hintText: "Address Line 2"),
              ),
              const SizedBox(height: 12),

              const Text("City", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
                        const Text("State", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
                        const Text("Zip Code", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        TextFormField(
                          controller: controller.zipCode,
                          decoration: const InputDecoration(hintText: "Zip Code"),
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
              const Spacer(),
              LongButton(
                label: "Save",
                onPressed: () => controller.updateAddress(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
