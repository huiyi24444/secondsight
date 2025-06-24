import 'dart:math';
import 'dart:ui'; // Add this import for Point class

class Point3D {
  final double x, y, z;
  Point3D(this.x, this.y, this.z);
}

class PoseLandmarks {
  final Map<String, Point3D> landmarks;

  PoseLandmarks(this.landmarks);

  Point3D? get leftShoulder => landmarks['left_shoulder'];
  Point3D? get rightShoulder => landmarks['right_shoulder'];
  Point3D? get leftHip => landmarks['left_hip'];
  Point3D? get rightHip => landmarks['right_hip'];

  double get shoulderWidth {
    if (leftShoulder == null || rightShoulder == null) return 0;
    return (rightShoulder!.x - leftShoulder!.x).abs();
  }

  double get torsoHeight {
    if (leftShoulder == null || leftHip == null) return 0;
    return (leftHip!.y - leftShoulder!.y).abs();
  }

  Point get torsoCenter {
    if (leftShoulder == null || rightHip == null) return Point(0.5, 0.5);
    return Point(
      (leftShoulder!.x + rightHip!.x) / 2,
      (leftShoulder!.y + rightHip!.y) / 2,
    );
  }
}