import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import '../models/pose_landmarks.dart';
import '../services/pose_detection_service.dart';
import 'clothing_overlay_painter.dart';

class VirtualTryOnView extends StatefulWidget {
  final String clothingImageUrl;
  final Size cameraSize;
  final CameraController cameraController;
  final String clothingType;

  const VirtualTryOnView({
    Key? key,
    required this.clothingImageUrl,
    required this.cameraSize,
    required this.cameraController,
    this.clothingType = 'upper',
  }) : super(key: key);

  @override
  _VirtualTryOnViewState createState() => _VirtualTryOnViewState();
}

class _VirtualTryOnViewState extends State<VirtualTryOnView> {
  static const MethodChannel _methodChannel =
  MethodChannel('edu.tar.my.secondsight/pose_methods');
  final PoseDetectionService _poseService = PoseDetectionService();
  PoseLandmarks? _currentPose;
  ui.Image? _clothingImage;
  bool _isProcessing = false;
  bool _isLoadingImage = true;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _loadClothingImage();
    _listenToPoseUpdates();
    _startImageStream(widget.cameraController);
  }

  Future<void> _loadClothingImage() async {
    setState(() => _isLoadingImage = true);

    try {
      // Check if it's a network URL or asset path
      if (widget.clothingImageUrl.startsWith('http')) {
        await _loadNetworkImage();
      } else if (widget.clothingImageUrl.startsWith('assets')) {
        await _loadAssetImage();
      } else {
        throw Exception('Invalid image URL format');
      }
    } catch (e) {
      print('Error loading clothing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load clothing image')),
        );
      }
    } finally {
      setState(() => _isLoadingImage = false);
    }
  }

  Future<void> _loadNetworkImage() async {
    try {
      print('Loading network image from: ${widget.clothingImageUrl}');

      // Download image from Firebase Storage URL
      final response = await http.get(Uri.parse(widget.clothingImageUrl));

      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;

        // Decode image
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();

        setState(() {
          _clothingImage = frameInfo.image;
          print('Network image loaded: ${_clothingImage!.width}x${_clothingImage!.height}');
        });
      } else {
        throw Exception('Failed to load image: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading network image: $e');
      rethrow;
    }
  }

  Future<void> _loadAssetImage() async {
    try {
      print('Loading asset image from: ${widget.clothingImageUrl}');

      final ByteData data = await rootBundle.load(widget.clothingImageUrl);
      final Uint8List bytes = data.buffer.asUint8List();

      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();

      setState(() {
        _clothingImage = frameInfo.image;
        print('Asset image loaded: ${_clothingImage!.width}x${_clothingImage!.height}');
      });
    } catch (e) {
      print('Error loading asset image: $e');
      rethrow;
    }
  }

  void _listenToPoseUpdates() {
    _poseService.poseStream.listen((poseData) {
      if (poseData.isEmpty) {
        setState(() {
          _currentPose = null;
        });
        return;
      }

      final mapped = poseData.map((k, v) {
        final point = Point3D(
          (v['x'] ?? 0).toDouble(),
          (v['y'] ?? 0).toDouble(),
          (v['z'] ?? 0).toDouble(),
        );
        return MapEntry(k, point);
      });

      setState(() {
        _currentPose = PoseLandmarks(mapped);
      });
    });
  }

  void _startImageStream(CameraController controller) {
    controller.startImageStream((CameraImage image) async {
      if (!_isProcessing) {
        _isProcessing = true;

        if (_frameCount % 10 == 0) {
          await _processFrame(image);
        }
        _frameCount++;

        _isProcessing = false;
      }
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final Uint8List yuv = _convertCameraImageToYuv(image);

      await _methodChannel.invokeMethod('processFrame', {
        'imageBytes': yuv,
        'width': image.width,
        'height': image.height,
      });
    } catch (e) {
      print('Error processing frame: $e');
    }
  }

  Uint8List _convertCameraImageToYuv(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera preview
        CameraPreview(widget.cameraController),

        // Clothing overlay
        SizedBox.expand(
            child: CustomPaint(
              painter: ClothingOverlayPainter(
                pose: _currentPose,
                clothingImage: _clothingImage,
                cameraSize: widget.cameraSize,
                clothingType: widget.clothingType,
              ),
            )
        ),

        // Loading indicator for image
        if (_isLoadingImage)
          Center(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    'Loading clothing...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

        // Debug overlay
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            color: Colors.black54,
            padding: EdgeInsets.all(8),
            child: Text(
              'Pose: ${_currentPose != null ? "Detected" : "Not detected"}\n'
                  'Landmarks: ${_currentPose?.landmarks.length ?? 0}\n'
                  'Type: ${widget.clothingType}\n'
                  'Image: ${_clothingImage != null ? "Loaded" : _isLoadingImage ? "Loading..." : "Failed"}',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}