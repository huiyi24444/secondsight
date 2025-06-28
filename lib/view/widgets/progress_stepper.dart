import 'package:flutter/material.dart';

class ProgressStepper extends StatelessWidget {
  final String title;
  final List<String> steps;
  final int currentStep;
  final Color activeColor;
  final Color inactiveColor;
  final Color completedColor;
  final double stepperHeight;
  final double circleSize;
  final TextStyle? titleStyle;
  final TextStyle? stepTextStyle;

  const ProgressStepper({
    Key? key,
    required this.title,
    required this.steps,
    required this.currentStep,
    this.activeColor = Colors.purple,
    this.inactiveColor = Colors.grey,
    this.completedColor = Colors.purple,
    this.stepperHeight = 4.0,
    this.circleSize = 16.0,
    this.titleStyle,
    this.stepTextStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: titleStyle ??
                  const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600
                  ),
            ),
            // Current status badge

          ],
        ),

        const SizedBox(height: 16),

        // Progress Stepper
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              // Circles and connecting lines
              SizedBox(
                height: circleSize,
                child: Row(
                  children: _buildStepperRow(),
                ),
              ),

              const SizedBox(height: 8),

              // Step labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: steps.asMap().entries.map((entry) {
                  int index = entry.key;
                  String step = entry.value;

                  return Expanded(
                    child: Text(
                      step,
                      textAlign: _getTextAlignment(index),
                      style: stepTextStyle ??
                          TextStyle(
                            fontSize: 12,
                            color: index <= currentStep ?
                            _getStepColor(index) :
                            inactiveColor,
                            fontWeight: index == currentStep ?
                            FontWeight.w600 :
                            FontWeight.w400,
                          ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStepperRow() {
    List<Widget> widgets = [];

    for (int i = 0; i < steps.length; i++) {
      // Add circle
      widgets.add(
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStepColor(i),
          ),
        ),
      );

      // Add connecting line (except for the last step)
      if (i < steps.length - 1) {
        widgets.add(
          Expanded(
            child: Container(
              height: stepperHeight,
              color: i < currentStep ? completedColor : inactiveColor,
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Color _getStepColor(int index) {
    if (index < currentStep) {
      return completedColor;
    } else if (index == currentStep) {
      return activeColor;
    } else {
      return inactiveColor;
    }
  }

  Color _getCurrentStatusColor() {
    return activeColor;
  }

  TextAlign _getTextAlignment(int index) {
    if (index == 0) return TextAlign.start;
    if (index == steps.length - 1) return TextAlign.end;
    return TextAlign.center;
  }
}

// Example usage classes for different scenarios

class ReturnStatusStepper extends StatelessWidget {
  final String returnStatus;

  const ReturnStatusStepper({
    Key? key,
    required this.returnStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final steps = ['Request Submitted', 'Pending Approval', 'Request Approved'];
    int currentStep = _getCurrentStep(returnStatus);

    return ProgressStepper(
      title: 'Return & Refund',
      steps: steps,
      currentStep: currentStep,
      activeColor: Colors.purple,
      completedColor: Colors.purple,
    );
  }

  int _getCurrentStep(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
      case 'request_submitted':
        return 0;
      case 'pending':
      case 'pending_approval':
        return 1;
      case 'approved':
      case 'request_approved':
        return 2;
      default:
        return 0;
    }
  }
}

class DeliveryStatusStepper extends StatelessWidget {
  final String deliveryStatus;

  const DeliveryStatusStepper({
    Key? key,
    required this.deliveryStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final steps = ['Order Placed', 'Processing', 'Shipped', 'Delivered'];
    int currentStep = _getCurrentStep(deliveryStatus);

    return ProgressStepper(
      title: 'Delivery Status',
      steps: steps,
      currentStep: currentStep,
      activeColor: Colors.green,
      completedColor: Colors.green,
    );
  }

  int _getCurrentStep(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
      case 'order_placed':
        return 0;
      case 'processing':
        return 1;
      case 'shipped':
        return 2;
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }
}

class OrderStatusStepper extends StatelessWidget {
  final String orderStatus;

  const OrderStatusStepper({
    Key? key,
    required this.orderStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final steps = ['Confirmed', 'Preparing', 'Ready', 'Completed'];
    int currentStep = _getCurrentStep(orderStatus);

    return ProgressStepper(
      title: 'Order Status',
      steps: steps,
      currentStep: currentStep,
      activeColor: Colors.orange,
      completedColor: Colors.orange,
    );
  }

  int _getCurrentStep(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 0;
      case 'preparing':
        return 1;
      case 'ready':
        return 2;
      case 'completed':
        return 3;
      default:
        return 0;
    }
  }
}

// Usage Examples:

/*
// For Return Status
ReturnStatusStepper(
  returnStatus: request.returnStatus,
)

// For Delivery Status
DeliveryStatusStepper(
  deliveryStatus: order.deliveryStatus,
)

// For Order Status
OrderStatusStepper(
  orderStatus: order.status,
)

// Custom usage
ProgressStepper(
  title: 'Custom Process',
  steps: ['Step 1', 'Step 2', 'Step 3', 'Step 4'],
  currentStep: 1,
  activeColor: Colors.blue,
  completedColor: Colors.blue,
  titleStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  stepTextStyle: TextStyle(fontSize: 11),
)
*/