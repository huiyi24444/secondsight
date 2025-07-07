// CONTROLLER FILE: edit_profile_controller.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../model/profile_model.dart';

class EditProfileController {
  final BuildContext context;
  final String userId;
  final ProfileModel profile;
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  File? imageFile;
  String? profilePicUrl;
  bool isLoading = false;

  EditProfileController(this.context, this.userId, this.profile) {
    nameController.text = profile.fullName;
    phoneController.text = profile.phoneNum > 0 ? profile.phoneNum.toString() : '';
    profilePicUrl = profile.profilePic;
  }

  void disposeControllers() {
    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> pickImage(Function setState) async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: _tileIcon(Icons.camera_alt),
                  title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                    if (photo != null) {
                      setState(() {
                        imageFile = File(photo.path);
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: _tileIcon(Icons.photo_library),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                    if (photo != null) {
                      setState(() {
                        imageFile = File(photo.path);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tileIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF8E6CEF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: const Color(0xFF8E6CEF)),
    );
  }

  Future<String?> _uploadImage() async {
    if (imageFile == null) return profilePicUrl;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await storageRef.putFile(imageFile!);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> saveProfile(Function setState) async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final newProfilePicUrl = await _uploadImage();
      final phoneText = phoneController.text.trim();
      final Map<String, dynamic> updateData = {
        'fullName': nameController.text.trim(),
        'phoneNum': phoneText.isNotEmpty
            ? (int.tryParse(phoneText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
            : 0,
      };
      if (newProfilePicUrl != null) updateData['profilePic'] = newProfilePicUrl;

      await FirebaseFirestore.instance.collection('users').doc(userId).update(updateData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Color(0xFF8E6CEF),
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (context.mounted) setState(() => isLoading = false);
    }
  }

  Widget buildProfileImage() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF8E6CEF).withOpacity(0.2), width: 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: imageFile != null
                    ? Image.file(imageFile!, fit: BoxFit.cover)
                    : Image.network(
                  profilePicUrl ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) => Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.person, size: 40, color: Colors.grey[400]),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => pickImage((fn) => fn()),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E6CEF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildForm(Function setState) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Full Name'),
            const SizedBox(height: 8),
            TextFormField(
              controller: nameController,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: _inputDecoration('Enter your full name', Icons.person_outline),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Please enter your name';
                if (value.trim().length < 2) return 'Name must be at least 2 characters';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _label('Phone Number'),
            const SizedBox(height: 8),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: _inputDecoration('Enter your phone number', Icons.phone_outlined),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!RegExp(r'^\d{11}$').hasMatch(value)) {
                    return 'Please enter a valid 10-digit phone number';
                  }
                }

                return null;
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : () => saveProfile(setState),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E6CEF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  disabledBackgroundColor: const Color(0xFF8E6CEF).withOpacity(0.6),
                ),
                child: isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700], letterSpacing: -0.2),
  );

  InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w400),
    filled: true,
    fillColor: const Color(0xFFFAFAFA),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    prefixIcon: Icon(icon, color: Colors.grey[600], size: 22),
  );
}
