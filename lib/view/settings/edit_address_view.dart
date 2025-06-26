import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/custom_back_button.dart';
import '../widgets/long_button.dart';

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
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullName;
  late TextEditingController _phoneNum;
  late TextEditingController _streetOne;
  late TextEditingController _streetTwo;
  late TextEditingController _city;
  late TextEditingController _state;
  late TextEditingController _zipCode;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: widget.initialData['fullName'] ?? '');
    _phoneNum = TextEditingController(text: widget.initialData['phoneNum']?.toString() ?? '');
    _streetOne = TextEditingController(text: widget.initialData['streetone'] ?? '');
    _streetTwo = TextEditingController(text: widget.initialData['streettwo'] ?? '');
    _city = TextEditingController(text: widget.initialData['city'] ?? '');
    _state = TextEditingController(text: widget.initialData['state'] ?? '');
    _zipCode = TextEditingController(text: widget.initialData['zipCode']?.toString() ?? '');
    _isDefault = widget.initialData['isDefault'] ?? false;
  }

  void _updateAddress() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('address')
          .doc(widget.addressId)
          .update({
        'fullName': _fullName.text,
        'phoneNum': int.tryParse(_phoneNum.text) ?? 0,
        'isDefault': _isDefault,
        'streetone': _streetOne.text,
        'streettwo': _streetTwo.text,
        'city': _city.text,
        'state': _state.text,
        'zipCode': int.tryParse(_zipCode.text) ?? 0,
      });

      Navigator.pop(context);
    }
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
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Full Name", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(hintText: "Full Name"),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              const Text("Phone Number", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: _phoneNum,
                decoration: const InputDecoration(hintText: "Phone Number"),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 25),

              const Text("Street Address", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: _streetOne,
                decoration: const InputDecoration(hintText: "Street Address"),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              const Text("Address Line 2", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: _streetTwo,
                decoration: const InputDecoration(hintText: "Address Line 2"),
              ),
              const SizedBox(height: 12),

              const Text("City", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: _city,
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
                          controller: _state,
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
                          controller: _zipCode,
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
                    value: _isDefault,
                    onChanged: (value) {
                      setState(() {
                        _isDefault = value ?? false;
                      });
                    },
                  ),
                  const Text("Set as default address"),
                ],
              ),
              const Spacer(),
              LongButton(
                label: "Save",
                onPressed: _updateAddress,
              ),
            ],
          ),

        ),
      ),
    );
  }
}
