// FILE: widgets/add_customer_dialog.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddCustomerDialog extends StatefulWidget {
  final Function onCustomerAdded;

  const AddCustomerDialog({Key? key, required this.onCustomerAdded}) : super(key: key);

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  String selectedCountry = 'MALAYSIA';
  bool isLoading = false;

  Future<void> _addCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final userRef = _firestore.collection('Customer').doc(); // generate userId here

      final customerData = {
        'email': _emailController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'phoneNum': int.tryParse(_phoneController.text.trim()) ?? 0,
        'profilePic': '',
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'address': {
          'country': selectedCountry,
        },
      };

      await userRef.set(customerData);

      Navigator.pop(context);
      widget.onCustomerAdded();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding customer: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(30),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add a New Customer',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text('Customer Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),

              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) =>
                value == null || value.isEmpty ? 'Please enter full name' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) =>
                value == null || value.isEmpty ? 'Please enter a username' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter email';
                  if (!value.contains('@')) return 'Please enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Container(
                    width: 120,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedCountry,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: ['MALAYSIA', 'SINGAPORE', 'USA', 'UK'].map((country) {
                        return DropdownMenuItem(
                          value: country,
                          child: Row(
                            children: [
                              const Icon(Icons.flag, size: 16),
                              const SizedBox(width: 5),
                              Text(country, style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedCountry = value!);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) =>
                      value == null || value.isEmpty ? 'Enter phone number' : null,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: isLoading ? null : _addCustomer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                    child: isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
