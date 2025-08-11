import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_wrapper.dart';
import '../products/homepage.dart';
class IntroScreen extends StatefulWidget {
  @override
  _IntroScreenState createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _imagesPreloaded = false;

  static const String image1 = 'https://firebasestorage.googleapis.com/v0/b/secondsight-5cba4.firebasestorage.app/o/intro%2Feco-friendly-clothing-brand-recycling-tag-plastic-free-apparel-ecological-garment-female-fashion-woman-buying-natural-material-clothes.png?alt=media&token=66bc599e-16c9-46fe-a5e6-7d5cf4ad713c';
  static const String image2 = 'https://firebasestorage.googleapis.com/v0/b/secondsight-5cba4.firebasestorage.app/o/intro%2Fvtooo.png?alt=media&token=fa7aba66-7bbd-481f-a8c0-6ffcff8de5e2';
  static const String image3 = 'https://firebasestorage.googleapis.com/v0/b/secondsight-5cba4.firebasestorage.app/o/intro%2Fpersonal-stylist-abstract-concept-vector-illustration-shopping-consultant-beauty-blogger-business-clothes-tailor-workspace-fashion-man-woman-style-dressing-room-abstract-metaphor.png?alt=media&token=3a87354b-891e-4beb-b7ec-58747dd438fe';


  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload images only once when dependencies are ready
    if (!_imagesPreloaded) {
      _preloadImages();
      _imagesPreloaded = true;
    }
  }

  void _preloadImages() {
    precacheImage(NetworkImage(image1), context);
    precacheImage(NetworkImage(image2), context);
    precacheImage(NetworkImage(image3), context);
  }


  void _onIntroFinished(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_intro', true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const AuthWrapper(authenticatedWidget: MyHomePage()),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              _buildPage1(context),
              _buildPage2(context),
              _buildPage3(context),
            ],
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                        (index) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 5),
                      width: _currentPage == index ? 25 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Color(0xFF8B5CF6)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: Offset(0, 2), // Shadow position
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: _currentPage == 2 ? 25 : 30),
                if (_currentPage < 2)
                  TextButton(
                    onPressed: () {
                      _pageController.nextPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Text(
                      'Next',
                      style: TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      _onIntroFinished(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF8B5CF6),
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizedImage(String imageUrl, double height) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: height,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF8B5CF6),
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.error_outline,
          color: Colors.grey[600],
          size: 50,
        ),
      ),
      // Enable memory and disk caching
      memCacheHeight: 500,
      memCacheWidth: 500,
      maxHeightDiskCache: 1000,
      maxWidthDiskCache: 1000,
    );
  }

  Widget _buildPage1(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF3E5F5),
            Color(0xFFEDE7F6),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(height: 80),
              Container(
                height: 350,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildOptimizedImage(image1, 500),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Shop Sustainably',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Discover pre-loved fashion that’s kind to your wallet and the planet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF475569),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage2(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFFFFF8E1),
            Color(0xFFFFF3B0),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(height: 50),
              Container(
                height: 380,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildOptimizedImage(image2, 400),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Try Before You Buy',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'See how clothes fit on you with our real-time virtual try-on experience.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF475569),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage3(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFDDD6FE),
            Color(0xFFC4B5FD),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(height: 55),
              Container(
                height: 385,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(
                     'https://firebasestorage.googleapis.com/v0/b/secondsight-5cba4.firebasestorage.app/o/intro%2Fpersonal-stylist-abstract-concept-vector-illustration-shopping-consultant-beauty-blogger-business-clothes-tailor-workspace-fashion-man-woman-style-dressing-room-abstract-metaphor.png?alt=media&token=3a87354b-891e-4beb-b7ec-58747dd438fe',
                      height: 400,
                      fit: BoxFit.cover,
                    ),
                  ],
                ),
              ),
            SizedBox(height: 0),
              Text(
                'Style, Just for You',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Experience fashion digitally! Try on clothes virtually and find your perfect style from anywhere.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF475569),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LadderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFF1E293B)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw ladder sides
    canvas.drawLine(Offset(10, 0), Offset(10, size.height), paint);
    canvas.drawLine(Offset(30, 0), Offset(30, size.height), paint);

    // Draw ladder steps
    for (int i = 0; i < 5; i++) {
      double y = i * 20.0 + 10;
      canvas.drawLine(Offset(10, y), Offset(30, y), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;


}