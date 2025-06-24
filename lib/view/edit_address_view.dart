import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  late TextEditingController _streetOne;
  late TextEditingController _streetTwo;
  late TextEditingController _city;
  late TextEditingController _state;
  late TextEditingController _zipCode;

  @override
  void initState() {
    super.initState();
    _streetOne = TextEditingController(text: widget.initialData['streetone']);
    _streetTwo = TextEditingController(text: widget.initialData['streettwo']);
    _city = TextEditingController(text: widget.initialData['city']);
    _state = TextEditingController(text: widget.initialData['state']);
    _zipCode = TextEditingController(text: widget.initialData['zipCode'].toString());
  }

  void _updateAddress() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('address')
          .doc(widget.addressId)
          .update({
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
      appBar: AppBar(title: const Text("Edit Address")),
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
                  onPressed: _updateAddress,
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
