import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:secondsight/services/auth_provider.dart';
import 'package:secondsight/services/auth_wrapper.dart';
import 'package:secondsight/view/checkout/order_success_view.dart';
import 'package:secondsight/admin_main.dart';
import 'package:secondsight/view/login/forgot_password_view.dart';
import 'package:secondsight/view/login/intro_decision_view.dart';
import 'package:secondsight/view/login/login_view.dart';
import 'package:secondsight/view/login/register_view.dart';
import 'package:secondsight/view/login/splash_screen.dart';
import 'package:secondsight/view/login/verification_view.dart';
import 'view/products/homepage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:secondsight/view/products/product_view.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:secondsight/web/admin/dashboard/admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Open boxes for offline storage
  await Hive.openBox('recommendations');
  await Hive.openBox('user_preferences');
  await Hive.openBox('products_cache');
  await Hive.openBox('view_history');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    Stripe.publishableKey = 'pk_test_51RdqXPQSp3H55udZMewh3I9eilxrid02WSapRFKsq2hvoogenAFbSa5TnMbU4IOcRUZemfqBXPCvS1Rd4izRF2wf00KZr3wv10';
    await Stripe.instance.applySettings();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
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
          primary: const Color(0xFF8E6CEF),
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
        fontFamily: 'Gabarito',
        useMaterial3: true,
      ),
      home: const SplashScreen(),  // ← now shows intro only once
      debugShowCheckedModeBanner: false,

      routes: {
        '/intro': (context) => const IntroDecisionScreen(),
        '/login': (context) => const LoginView(),
        '/register': (context) => const RegisterView(),
        '/home': (context) => const MyHomePage(),
        '/forgot-password': (context) => const ForgotPasswordView(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/email-verification') {
          final args = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => EmailVerificationView(email: args),
          );
        }
        return null;
      },
    );
  }
}

// Example Home Screen - Replace with your actual home screen
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? 'User',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'User ID: ${user?.uid ?? 'N/A'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (user != null && !user.emailVerified) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text('Email not verified'),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            '/email-verification',
                            arguments: user.email ?? '',
                          );
                        },
                        child: const Text('Verify now'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}