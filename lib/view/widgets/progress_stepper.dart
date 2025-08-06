import 'package:flutter/material.dart';

import '../../model/return_request_model.dart';

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
  final ReturnRequestModel request; // Add the request model to access dates

  const ReturnStatusStepper({
    Key? key,
    required this.returnStatus,
    required this.request,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusSteps = _getReturnStatusSteps();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Return & Refund Status',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: List.generate(statusSteps.length, (index) {
            final step = statusSteps[index];
            final isLast = index == statusSteps.length - 1;
            final isActive = step['isActive'] as bool;
            final isCompleted = step['isCompleted'] as bool;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline indicator
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? Colors.purple
                            : Colors.grey[300],
                        border: isActive && !isCompleted
                            ? Border.all(
                          color: Colors.purple,
                          width: 2,
                        )
                            : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                            : Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? Colors.purple
                                : Colors.grey[400],
                          ),
                        ),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        color: isCompleted
                            ? (statusSteps[index + 1]['isCompleted'] as bool
                            ? Colors.purple
                            : Colors.grey[300])
                            : Colors.grey[300],
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Status info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['title'] as String,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isCompleted || isActive
                                ? Colors.black87
                                : Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (step['date'] != null)
                          Text(
                            _formatStatusDate(step['date'] as DateTime),
                            style: TextStyle(
                              fontSize: 13,
                              color: isCompleted || isActive
                                  ? Colors.grey[600]
                                  : Colors.grey[400],
                            ),
                          )
                        else
                          Text(
                            step['pendingText'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getReturnStatusSteps() {
    final status = returnStatus.toLowerCase();

    return [
      {
        'title': 'Pending Approval',
        'isCompleted': _isStepCompleted('pending_approval'),
        'isActive': status == 'pending_approval',
        'date': request.returnDate?.toDate(), // Use submission date
        'pendingText': 'Awaiting approval',
      },
      {
        'title': 'Approved',
        'isCompleted': _isStepCompleted('approved'),
        'isActive': status == 'approved',
        'date': request.approvedDate?.toDate(),
        'pendingText': 'Awaiting collection',
      },
      {
        'title': 'Pending Inspection',
        'isCompleted': _isStepCompleted('pending_inspection'),
        'isActive': status == 'pending_inspection',
        'date': request.pendinginspectionDate?.toDate(),
        'pendingText': 'Waiting for inspection',
      },
      {
        'title': 'Inspection Completed',
        'isCompleted': _isStepCompleted('completed_inspection'),
        'isActive': status == 'completed_inspection',
        'date': request.completedinsepectionDate?.toDate(),
        'pendingText': 'Processing refund decision',
      },
      {
        'title': status == 'refunded' ? 'Refunded' : status == 'not_refunded' ? 'Not Refunded' : 'Final Status',
        'isCompleted': _isStepCompleted('refunded') || _isStepCompleted('not_refunded'),
        'isActive': status == 'refunded' || status == 'not_refunded',
        'date': request.completedDate?.toDate(),
        'pendingText': 'Finalizing return',
      },
    ];
  }


  bool _isStepCompleted(String stepStatus) {
    final currentStatus = returnStatus.toLowerCase();

    switch (stepStatus) {
      case 'pending_approval':
        return [
          'approved',
          'pending_inspection',
          'completed_inspection',
          'refunded',
          'not_refunded',
          'rejected',
          'cancelled',
        ].contains(currentStatus);

      case 'approved':
        return [
          'pending_inspection',
          'completed_inspection',
          'refunded',
          'not_refunded',
        ].contains(currentStatus);

      case 'pending_inspection':
        return ['completed_inspection', 'refunded', 'not_refunded'].contains(currentStatus);

      case 'completed_inspection':
        return ['refunded', 'not_refunded'].contains(currentStatus);

      case 'refunded':
        return currentStatus == 'refunded';

      case 'not_refunded':
        return currentStatus == 'not_refunded';

      default:
        return false;
    }
  }

  String _formatStatusDate(DateTime date) {
    // You can customize this format as needed
    return "${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
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