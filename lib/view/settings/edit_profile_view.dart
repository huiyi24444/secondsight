import 'package:flutter/material.dart';
import '../../controller/settings/edit_profile_controller.dart';
import '../../model/profile_model.dart';
import '../widgets/custom_back_button.dart';


class EditProfileView extends StatefulWidget {
  final String userId;
  final ProfileModel profile;

  const EditProfileView({
    super.key,
    required this.userId,
    required this.profile,
  });

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  late EditProfileController controller;

  @override
  void initState() {
    super.initState();
    controller = EditProfileController(context, widget.userId, widget.profile);
  }

  @override
  void dispose() {
    controller.disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            controller.buildProfileImage(),
            const SizedBox(height: 8),
            controller.buildForm(setState),
          ],
        ),
      ),
    );
  }
}