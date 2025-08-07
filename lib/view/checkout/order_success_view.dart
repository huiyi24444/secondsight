import 'package:flutter/material.dart';

import '../order/order_details_view.dart';
import '../products/homepage.dart';


class OrderSuccessScreen extends StatelessWidget {
  final String userId;
  final String orderId;

  const OrderSuccessScreen({
    Key? key,
    required this.userId,
    required this.orderId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF8B5CF6),
      body: SafeArea(
        bottom: false, // Don't respect bottom safe area
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Center(
                child: Image.asset(
                  'assets/images/order-successful.png',
                  width: 600, // Adjust as needed (up to 1000)
                  height: 600,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Text(
                          'Order Placed Successfully',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'You will receive an email confirmation shortly.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrderDetailsView(orderId: orderId, userId: userId,),
                                ),
                              );

                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF8B5CF6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'See Order details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 6),
                        TextButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => MyHomePage()), // Replace with your actual homepage
                                  (route) => false,
                            );
                          },
                          child: Text(
                            'Back to Homepage',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8B5CF6),
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}