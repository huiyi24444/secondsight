import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddAddressController extends ChangeNotifier {
  final String userId;
  final formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final phoneNumController = TextEditingController();
  final streetOneController = TextEditingController();
  final streetTwoController = TextEditingController();
  final cityController = TextEditingController();
  final zipCodeController = TextEditingController();

  final List<String> malaysianStates = [
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

  String selectedState = 'Penang';
  bool isDefault = false;

  AddAddressController({required this.userId});

  Future<void> saveAddress(BuildContext context) async {
    if (formKey.currentState!.validate()) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('address')
          .add({
        'fullName': fullNameController.text,
        'phoneNum': int.tryParse(phoneNumController.text) ?? 0,
        'isDefault': isDefault,
        'streetone': streetOneController.text,
        'streettwo': streetTwoController.text,
        'city': cityController.text,
        'state': selectedState,
        'zipCode': int.tryParse(zipCodeController.text) ?? 0,
      });

      Navigator.pop(context);
    }
  }

  void updateSelectedState(String? value) {
    if (value != null) {
      selectedState = value;
      notifyListeners(); // Updates any listening widgets
    }
  }

  void updateDefault(bool? value) {
    isDefault = value ?? false;
    notifyListeners();
  }

  void dispose() {
    fullNameController.dispose();
    phoneNumController.dispose();
    streetOneController.dispose();
    streetTwoController.dispose();
    cityController.dispose();
    zipCodeController.dispose();
  }
}
