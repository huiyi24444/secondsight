import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'intro_decision_view.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    // Start the fade animation
    _fadeController.forward();

    // Navigate to intro screen after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _navigateToIntroScreen();
    });
  }

  void _navigateToIntroScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const IntroDecisionScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top padding
              const SizedBox(height: 80),

              // Logo section
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  child: Image.asset(
                    'assets/images/secondsight_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 5),

              // Slogan
              Center(
                child: const Text(
                  'Where Style Finds a Second Life',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF8E6CEF),
                    fontFamily: 'Gabarito',
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 5),

              // Animation section
              Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: _buildAnimationWidget(),
                ),
              ),

              // Bottom padding
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // Move these methods INSIDE the class
  Widget _buildAnimationWidget() {
    return FutureBuilder(
      future: _checkAssetExists(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == true) {
          // Asset exists, load Lottie animation
          return Lottie.asset(
            'assets/animations/loading.json',
            repeat: true,
            animate: true,
            errorBuilder: (context, error, stackTrace) {
              print('Lottie error: $error');
              return _buildFallbackAnimation();
            },
          );
        } else {
          // Asset doesn't exist or error, show fallback
          return _buildFallbackAnimation();
        }
      },
    );
  }

  Widget _buildFallbackAnimation() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF8E6CEF).withOpacity(0.2), // Use your app's color
        borderRadius: BorderRadius.circular(50),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8E6CEF)),
          strokeWidth: 3,
        ),
      ),
    );
  }

  Future<bool> _checkAssetExists() async {
    try {
      await DefaultAssetBundle.of(context).loadString('assets/animations/loading.json');
      return true;
    } catch (e) {
      print('Asset loading error: $e');
      return false;
    }
  }
}