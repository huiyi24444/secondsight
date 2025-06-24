import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class CustomBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const CustomBackButton({Key? key, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedArrowLeft01,
          color: Colors.black,
          size: 40.0,
        ),
    );
  }
}
