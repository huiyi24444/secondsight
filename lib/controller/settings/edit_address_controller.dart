import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditAddressController {
  final String userId;
  final String addressId;
  final Map<String, dynamic> initialData;

  final formKey = GlobalKey<FormState>();

  late final TextEditingController fullName;
  late final TextEditingController phoneNum;
  late final TextEditingController streetOne;
  late final TextEditingController streetTwo;
  late final TextEditingController city;
  late final TextEditingController state;
  late final TextEditingController zipCode;
  late bool isDefault;

  EditAddressController({
    required this.userId,
    required this.addressId,
    required this.initialData,
  }) {
    fullName = TextEditingController(text: initialData['fullName'] ?? '');
    phoneNum = TextEditingController(text: initialData['phoneNum']?.toString() ?? '');
    streetOne = TextEditingController(text: initialData['streetone'] ?? '');
    streetTwo = TextEditingController(text: initialData['streettwo'] ?? '');
    city = TextEditingController(text: initialData['city'] ?? '');
    state = TextEditingController(text: initialData['state'] ?? '');
    zipCode = TextEditingController(text: initialData['zipCode']?.toString() ?? '');
    isDefault = initialData['isDefault'] ?? false;
  }

  Future<void> updateAddress(BuildContext context) async {
    if (formKey.currentState!.validate()) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('address')
          .doc(addressId)
          .update({
        'fullName': fullName.text,
        'phoneNum': int.tryParse(phoneNum.text) ?? 0,
        'isDefault': isDefault,
        'streetone': streetOne.text,
        'streettwo': streetTwo.text,
        'city': city.text,
        'state': state.text,
        'zipCode': int.tryParse(zipCode.text) ?? 0,
      });

      Navigator.pop(context);
    }
  }

  void dispose() {
    fullName.dispose();
    phoneNum.dispose();
    streetOne.dispose();
    streetTwo.dispose();
    city.dispose();
    state.dispose();
    zipCode.dispose();
  }
}
