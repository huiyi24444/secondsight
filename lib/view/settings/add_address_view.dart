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
  final _streetOne = TextEditingController();
  final _streetTwo = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zipCode = TextEditingController();

  void _saveAddress() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('address')
          .add({
        'streetone': _streetOne.text,
        'streettwo': _streetTwo.text,
        'city': _city.text,
        'state': _selectedState,
        'zipCode': int.parse(_zipCode.text),
      });

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const CustomBackButton(), // Use your custom back button here
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
            children: [
              TextFormField(controller: _streetOne, decoration: const InputDecoration(hintText: "Address Line 1"), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _streetTwo, decoration: const InputDecoration(hintText: "Address Line 2")),
              const SizedBox(height: 12),
              TextFormField(controller: _city, decoration: const InputDecoration(hintText: "City"), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
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
                  ),

                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _zipCode,
                      decoration: const InputDecoration(hintText: "Zip Code"),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
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
