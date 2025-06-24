import 'package:flutter/services.dart';

class PoseDetectionService {
  static const EventChannel _poseChannel =
  EventChannel('edu.tar.my.secondsight/pose_detection'); // Fixed channel name

  Stream<Map<String, dynamic>> get poseStream {
    return _poseChannel.receiveBroadcastStream()
        .map((data) => Map<String, dynamic>.from(data));
  }
}