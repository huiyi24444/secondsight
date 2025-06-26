import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/custom_back_button.dart';
import '../widgets/long_button.dart';

class AddAddressView extends StatefulWidget {
  final String userId;

  const AddAddressView({super.key, required this.userId});

  @override
  State<AddAddressView> createState() => _AddAddressViewState();
}

final List<String> _malaysianStates = [
  'Johor',
  'Kedah',
  'Kelantan',
  'Melaka',
  'Negeri Sembilan',
  'Pahang',
  'Penang',
  'Perak',
  'Perlis',
  'Sabah',
  'Sarawak',
  'Selangor',
  'Terengganu',
  'Kuala Lumpur',
  'Labuan',
  'Putrajaya',
];

String? _selectedState = 'Penang';

class _AddAddressViewState extends State<AddAddressView> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phoneNum = TextEditingController();
  final _streetOne = TextEditingController();
  final _streetTwo = TextEditingController();
  final _city = TextEditingController();
  final _zipCode = TextEditingController();
  bool _isDefault = false;

  void _saveAddress() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('address')
          .add({
        'fullName': _fullName.text,
        'phoneNum': int.tryParse(_phoneNum.text) ?? 0,
        'isDefault': _isDefault,
        'streetone': _streetOne.text,
        'streettwo': _streetTwo.text,
        'city': _city.text,
        'state': _selectedState,
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
        title: const Text("Add address"),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 16, left: 19, right: 19, bottom: 20),
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
              const Text("Address Line 1", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              TextFormField(
                controller: _streetOne,
                decoration: const InputDecoration(hintText: "Address Line 1"),
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
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedState,
                          decoration: const InputDecoration(hintText: "State"),
                          items: _malaysianStates
                              .map((state) => DropdownMenuItem(value: state, child: Text(state)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedState = value;
                            });
                          },
                          validator: (value) => value == null ? 'Required' : null,
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
                onPressed: _saveAddress,
              ),
            ],
          ),

        ),
      ),
    );
  }
}
