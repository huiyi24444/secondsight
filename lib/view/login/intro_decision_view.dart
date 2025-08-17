import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_wrapper.dart';
import '../products/homepage.dart';
import 'intro_view.dart'; // Add this import

class IntroDecisionScreen extends StatefulWidget {
  const IntroDecisionScreen({Key? key}) : super(key: key);

  @override
  State<IntroDecisionScreen> createState() => _IntroDecisionScreenState();
}

class _IntroDecisionScreenState extends State<IntroDecisionScreen> {
  bool _isLoading = true;
  bool _seenIntro = false;

  @override
  void initState() {
    super.initState();
    _checkIntroSeen();
  }

  Future<void> _checkIntroSeen() async {
    // Remove the SharedPreferences check and always show intro
    setState(() {
      _seenIntro = false; // Always set to false to show intro
      _isLoading = false;
    });

    // Always navigate to intro screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => IntroScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking intro status
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}