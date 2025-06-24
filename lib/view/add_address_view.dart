import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddAddressView extends StatefulWidget {
  final String userId;

  const AddAddressView({super.key, required this.userId});

  @override
  State<AddAddressView> createState() => _AddAddressViewState();
}

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
        'state': _state.text,
        'zipCode': int.parse(_zipCode.text),
      });

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Address")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _streetOne, decoration: const InputDecoration(hintText: "Street Address"), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _streetTwo, decoration: const InputDecoration(hintText: "Address Line 2")),
              const SizedBox(height: 12),
              TextFormField(controller: _city, decoration: const InputDecoration(hintText: "City"), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(controller: _state, decoration: const InputDecoration(hintText: "State"), validator: (v) => v!.isEmpty ? 'Required' : null),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                  onPressed: _saveAddress,
                  child: const Text("Save"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
