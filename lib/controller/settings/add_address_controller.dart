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
    if (!formKey.currentState!.validate()) return;

    final addressRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('address');

    final batch = FirebaseFirestore.instance.batch();

    if (isDefault) {
      // Step 1: Find existing default address and unset it
      final existingDefaultSnapshot =
      await addressRef.where('isDefault', isEqualTo: true).get();

      for (var doc in existingDefaultSnapshot.docs) {
        batch.update(doc.reference, {'isDefault': false});
      }
    }

    // Step 2: Create a new address doc reference
    final newAddressRef = addressRef.doc(); // auto-generated ID

    // Step 3: Set the new address data
    batch.set(newAddressRef, {
      'fullName': fullNameController.text.trim(),
      'phoneNum': int.tryParse(phoneNumController.text) ?? 0,
      'isDefault': isDefault,
      'streetone': streetOneController.text.trim(),
      'streettwo': streetTwoController.text.trim(),
      'city': cityController.text.trim(),
      'state': selectedState,
      'zipCode': int.tryParse(zipCodeController.text) ?? 0,
    });

    // Step 4: Commit all writes
    await batch.commit();

    // Step 5: Go back
    Navigator.pop(context);
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
