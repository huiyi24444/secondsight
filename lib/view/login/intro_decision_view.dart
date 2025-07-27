import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_wrapper.dart';
import '../products/homepage.dart';
import 'intro_view.dart';

class IntroDecisionScreen extends StatefulWidget {
  const IntroDecisionScreen({super.key});

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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _seenIntro = prefs.getBool('seen_intro') ?? false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _seenIntro ? const AuthWrapper(authenticatedWidget: MyHomePage()) : IntroScreen();
  }
}
