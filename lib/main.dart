import 'package:flutter/material.dart';
import 'package:secondsight/view/checkout/order_success_view.dart';
import 'view/products/homepage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:secondsight/view/products/product_view.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

// main file
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  Stripe.publishableKey = 'pk_test_51RdqXPQSp3H55udZMewh3I9eilxrid02WSapRFKsq2hvoogenAFbSa5TnMbU4IOcRUZemfqBXPCvS1Rd4izRF2wf00KZr3wv10';
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecondSight',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8E6CEF),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF8E6CEF), // explicitly define primary color
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8E6CEF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        fontFamily: 'Gabarito', // 👈 Your custom font name
        useMaterial3: true,
      ),


      home: const MyHomePage(),


    );
  }
}
