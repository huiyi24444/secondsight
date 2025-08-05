import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/pose_landmarks.dart';

// Skeleton joint pairs
const List<List<String>> jointConnections = [
  ['left_shoulder', 'right_shoulder'],
  ['left_shoulder', 'left_elbow'],
  ['left_elbow', 'left_wrist'],
  ['right_shoulder', 'right_elbow'],
  ['right_elbow', 'right_wrist'],
  ['left_shoulder', 'left_hip'],
  ['right_shoulder', 'right_hip'],
  ['left_hip', 'right_hip'],
  ['left_hip', 'left_knee'],
  ['left_knee', 'left_ankle'],
  ['right_hip', 'right_knee'],
  ['right_knee', 'right_ankle'],
];

const Set<String> faceLandmarks = {
  'landmark_0',  // nose
  'landmark_1',  // left_eye_inner
  'landmark_2',  // left_eye
  'landmark_3',  // left_eye_outer
  'landmark_4',  // right_eye_inner
  'landmark_5',  // right_eye
  'landmark_6',  // right_eye_outer
  'landmark_7',  // left_ear
  'landmark_8',  // right_ear
  'landmark_9',  // mouth_left
  'landmark_10', // mouth_right
};


class ClothingOverlayPainter extends CustomPainter {
  final PoseLandmarks? pose;
  final ui.Image? clothingImage;
  final Size cameraSize;
  final String clothingType; // Add this field

  ClothingOverlayPainter({
    required this.pose,
    required this.clothingImage,
    required this.cameraSize,
    this.clothingType = 'upper', // Default to upper
  });

  Offset transformLandmarkForDisplay(double x, double y, Size size) {
    final verticalOffset = size.height * 0.12;  // adjust height of pose landmark
    return Offset(
        (1.0 - y) * size.width,
        (1.0 - x) * size.height - verticalOffset
    );
  }

  bool _isInBounds(double x, double y, Size size) {
    return x >= 0 && x <= size.width && y >= 0 && y <= size.height;
  }

  // Main clothing overlay method that routes to specific type handlers
  void _drawClothingOverlay(Canvas canvas, Size size) {
    if (clothingImage == null || pose == null) return;

    switch (clothingType) {
      case 'upper':
        _drawUpperClothing(canvas, size);
        break;
      case 'lower':
        _drawLowerClothing(canvas, size);
        break;
      case 'full':
        _drawFullClothing(canvas, size);
        break;
      default:
        _drawUpperClothing(canvas, size); // Default to upper
    }
  }

  // Your existing shirt overlay logic, renamed for clarity
  void _drawUpperClothing(Canvas canvas, Size size) {
    if (pose!.leftShoulder == null || pose!.rightShoulder == null) return;

    // This is your existing _drawShirtOverlay logic
    final leftShoulder = transformLandmarkForDisplay(pose!.leftShoulder!.x, pose!.leftShoulder!.y, size);
    final rightShoulder = transformLandmarkForDisplay(pose!.rightShoulder!.x, pose!.rightShoulder!.y, size);

    final leftHip = pose!.leftHip != null ? transformLandmarkForDisplay(pose!.leftHip!.x, pose!.leftHip!.y, size) : null;
    final rightHip = pose!.rightHip != null ? transformLandmarkForDisplay(pose!.rightHip!.x, pose!.rightHip!.y, size) : null;

    final shoulderWidth = (rightShoulder.dx - leftShoulder.dx).abs();
    final baseScale = shoulderWidth / clothingImage!.width * 2.3;

    final confidenceScale = 1.0;

    double calculatePerspectiveRatio() {
      final dx = (rightShoulder.dx - leftShoulder.dx).abs();
      final dy = (rightShoulder.dy - leftShoulder.dy).abs();
      return dx / (dy + 0.001);
    }
    final perspectiveRatio = calculatePerspectiveRatio();
    final perspectiveScale = perspectiveRatio > 0.8 ? 1.0 : 0.85;

    final finalScale = baseScale * confidenceScale * perspectiveScale;

    final centerX = (leftShoulder.dx + rightShoulder.dx) / 2;
    final centerY = (leftShoulder.dy + rightShoulder.dy) / 2;

    double calculateTorsoLength() {
      if (leftHip == null || rightHip == null) return size.height * 0.2;
      final hipCenterY = (leftHip.dy + rightHip.dy) / 2;
      return hipCenterY - centerY;
    }
    final torsoLength = calculateTorsoLength();
    final adjustedY = centerY - (torsoLength * 0.15);  //adjust height of shirt

    final shoulderAngle = atan2(
      rightShoulder.dy - leftShoulder.dy,
      rightShoulder.dx - leftShoulder.dx,
    );

    canvas.save();
    canvas.translate(centerX, adjustedY);
    canvas.rotate(shoulderAngle);
    canvas.scale(finalScale);
    canvas.drawImage(
      clothingImage!,
      Offset(-clothingImage!.width / 2, 0),
      Paint()..color = Colors.white.withOpacity(0.9),
    );
    canvas.restore();

    _drawDebugInfo(canvas, size, shoulderWidth, finalScale, shoulderAngle);
  }

  // New method for lower body clothing (pants, skirts)
  void _drawLowerClothing(Canvas canvas, Size size) {
    if (pose!.leftHip == null || pose!.rightHip == null) return;

    final leftHip = transformLandmarkForDisplay(pose!.leftHip!.x, pose!.leftHip!.y, size);
    final rightHip = transformLandmarkForDisplay(pose!.rightHip!.x, pose!.rightHip!.y, size);

    // Optional knees for length reference
    final leftKnee = pose!.landmarks['left_knee'] != null
        ? transformLandmarkForDisplay(pose!.landmarks['left_knee']!.x, pose!.landmarks['left_knee']!.y, size)
        : null;
    final rightKnee = pose!.landmarks['right_knee'] != null
        ? transformLandmarkForDisplay(pose!.landmarks['right_knee']!.x, pose!.landmarks['right_knee']!.y, size)
        : null;

    final hipWidth = (rightHip.dx - leftHip.dx).abs();

    // IMPORTANT: Increase the scale factor to make bottoms appear wider
    // Instead of 2.0, use 2.5 or 3.0 to extend beyond hip landmarks
    final widthMultiplier = 6.5; // Adjust this value to control how much wider the bottoms appear
    final baseScale = hipWidth / clothingImage!.width * widthMultiplier;

    final centerX = (leftHip.dx + rightHip.dx) / 2;
    final centerY = (leftHip.dy + rightHip.dy) / 2;

    // Calculate hip angle for rotation
    final hipAngle = atan2(
      rightHip.dy - leftHip.dy,
      rightHip.dx - leftHip.dx,
    );

    // Adjust Y position - you can tweak this multiplier too
    final adjustedY = centerY - (hipWidth * 1.5); // Reduced from 0.75 to position it better

    canvas.save();
    canvas.translate(centerX, adjustedY);
    canvas.rotate(hipAngle);
    canvas.scale(baseScale);

    canvas.drawImage(
      clothingImage!,
      Offset(-clothingImage!.width / 2, 0),
      Paint()..color = Colors.white.withOpacity(0.9),
    );

    canvas.restore();

    // Optional: Add debug info for bottoms
    if (true) { // Set to true to see debug info
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Bottom Debug:\n'
              'Hip Width: ${hipWidth.toStringAsFixed(1)}\n'
              'Scale: ${baseScale.toStringAsFixed(2)}\n'
              'Width Multiplier: $widthMultiplier',
          style: TextStyle(color: Colors.orange, fontSize: 12, backgroundColor: Colors.black54),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(10, 200));
    }
  }

  // New method for full body clothing (dresses, jumpsuits)
  void _drawFullClothing(Canvas canvas, Size size) {
    if (pose!.leftShoulder == null || pose!.rightShoulder == null ||
        pose!.leftHip == null || pose!.rightHip == null) return;

    final leftShoulder = transformLandmarkForDisplay(pose!.leftShoulder!.x, pose!.leftShoulder!.y, size);
    final rightShoulder = transformLandmarkForDisplay(pose!.rightShoulder!.x, pose!.rightShoulder!.y, size);
    final leftHip = transformLandmarkForDisplay(pose!.leftHip!.x, pose!.leftHip!.y, size);
    final rightHip = transformLandmarkForDisplay(pose!.rightHip!.x, pose!.rightHip!.y, size);

    final shoulderWidth = (rightShoulder.dx - leftShoulder.dx).abs();
    final shoulderCenterY = (leftShoulder.dy + rightShoulder.dy) / 2;
    final hipCenterY = (leftHip.dy + rightHip.dy) / 2;
    final torsoLength = hipCenterY - shoulderCenterY;

    // Scale based on torso length for full body coverage
    final baseScale = torsoLength / clothingImage!.height * 10.8;

    final centerX = (leftShoulder.dx + rightShoulder.dx) / 2;
    final centerY = shoulderCenterY;

    final shoulderAngle = atan2(
      rightShoulder.dy - leftShoulder.dy,
      rightShoulder.dx - leftShoulder.dx,
    );

    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(shoulderAngle);
    canvas.scale(baseScale);
    canvas.drawImage(
      clothingImage!,
      Offset(-clothingImage!.width / 2, 0),
      Paint()..color = Colors.white.withOpacity(0.9),
    );
    canvas.restore();
  }

  void _drawDebugInfo(Canvas canvas, Size size, double shoulderWidth, double scale, double angle) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Type: $clothingType\n'  // Add clothing type to debug
            'Shoulder Width: ${shoulderWidth.toStringAsFixed(1)}\n'
            'Scale: ${scale.toStringAsFixed(2)}\n'
            'Angle: ${(angle * 180 / pi).toStringAsFixed(1)}°',
        style: TextStyle(color: Colors.yellow, fontSize: 12, backgroundColor: Colors.black54),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(10, 120));
  }

  @override
  void paint(Canvas canvas, Size size) {
    //canvas.drawRect(Rect.fromLTWH(10, 10, 100, 100), Paint()..color = Colors.purple);

    if (pose == null) return;

    // Draw clothing first (behind skeleton)
    if (clothingImage != null) {
      _drawClothingOverlay(canvas, size);
    }

    // Red dots for landmarks
    final dotPaint = Paint()..color = Colors.red;
    for (var entry in pose!.landmarks.entries) {
      final landmarkName = entry.key;
      final point = entry.value;

      // Skip drawing red dots for face landmarks
      if (faceLandmarks.contains(landmarkName)) {
        continue; // Skip this landmark
      }

      final rotated = transformLandmarkForDisplay(point.x, point.y, size);

      if (_isInBounds(rotated.dx, rotated.dy, size)) {
        canvas.drawCircle(rotated, 5, dotPaint);
      }
    }

    // Green skeleton lines
    final linePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3;

    for (var pair in jointConnections) {
      final pointA = pose!.landmarks[pair[0]];
      final pointB = pose!.landmarks[pair[1]];

      if (pointA != null && pointB != null) {
        final offsetA = transformLandmarkForDisplay(pointA.x, pointA.y, size);
        final offsetB = transformLandmarkForDisplay(pointB.x, pointB.y, size);

        if (_isInBounds(offsetA.dx, offsetA.dy, size) &&
            _isInBounds(offsetB.dx, offsetB.dy, size)) {
          canvas.drawLine(offsetA, offsetB, linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}