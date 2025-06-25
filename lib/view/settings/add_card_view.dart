// File: add_card_view.dart
import 'package:flutter/material.dart';
import '../../model/card_model.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/long_button.dart';

class AddCardView extends StatefulWidget {
  final Function(CardModel) onSave;
  const AddCardView({super.key, required this.onSave});

  @override
  State<AddCardView> createState() => _AddCardViewState();
}

class _AddCardViewState extends State<AddCardView> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _ccvController = TextEditingController();
  final _expController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const CustomBackButton(), // Use your custom back button here
        title: const Text("Add card"),
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
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Card Number'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ccvController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'CCV'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _expController,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(labelText: 'Exp'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Cardholder Name'),
              ),
              const Spacer(),
              //LongButton(
              //                 label: "Save",
              //                 onPressed: _saveCard,
              //               ),
            ],
          ),
        ),
      ),
    );
  }
}

