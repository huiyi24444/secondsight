import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Scale animation
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('first_time') ?? true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (isFirstTime) {
        await prefs.setBool('first_time', false);
        if (mounted) Navigator.of(context).pushReplacementNamed('/intro');
      } else {
        if (mounted) Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // same as first code
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 80),

                    // Logo
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Image.asset(
                        'assets/images/secondsight_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 5),

                    // Slogan
                    const Text(
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

                    const SizedBox(height: 5),

                    // Lottie or fallback
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: _buildAnimationWidget(),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimationWidget() {
    return FutureBuilder(
      future: _checkAssetExists(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == true) {
          return Lottie.asset(
            'assets/animations/loading.json',
            repeat: true,
            animate: true,
            errorBuilder: (context, error, stackTrace) {
              return _buildFallbackAnimation();
            },
          );
        } else {
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
        color: const Color(0xFF8E6CEF).withOpacity(0.2),
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
      await DefaultAssetBundle.of(context)
          .loadString('assets/animations/loading.json');
      return true;
    } catch (_) {
      return false;
    }
  }
}
