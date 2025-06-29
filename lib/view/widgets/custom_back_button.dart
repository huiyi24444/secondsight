import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';


import '../products/homepage.dart'; // Update path

class CustomBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const CustomBackButton({Key? key, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MyHomePage()),
          );
        }
      },
      icon: HugeIcon(
        icon: HugeIcons.strokeRoundedArrowLeft01,
        color: Colors.black,
        size: 40.0,
      ),
    );
  }
}
