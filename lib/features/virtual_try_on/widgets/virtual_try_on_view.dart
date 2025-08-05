import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
//import 'package:gallery_saver/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../../../view/widgets/custom_back_button.dart';
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
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  PoseLandmarks? _currentPose;
  ui.Image? _clothingImage;
  bool _isProcessing = false;
  bool _isLoadingImage = true;
  bool _isCapturing = false;
  int _frameCount = 0;
  List<File> _recentImages = [];
  String? _lastCapturedImagePath;

  // Add these for proper cleanup
  StreamSubscription? _poseSubscription;
  bool _isImageStreamActive = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializeVirtualTryOn();
    _loadRecentImages();
  }

  Future<void> _initializeVirtualTryOn() async {
    print('Initializing Virtual Try-On...');

    // Load clothing image first
    await _loadClothingImage();

    // Set up pose detection
    _setupPoseDetection();

    // Start image stream with delay to ensure everything is ready
    await Future.delayed(Duration(milliseconds: 1000)); // Increased delay
    await _startImageStream();
  }

  // Load recent images from app's directory
  Future<void> _loadRecentImages() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tryOnDir = Directory('${tempDir.path}/tryon_images');

      if (await tryOnDir.exists()) {
        final files = tryOnDir.listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.png'))
            .toList()
          ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        setState(() {
          _recentImages = files.take(10).toList(); // Keep last 10 images
        });
      }
    } catch (e) {
      print('Error loading recent images: $e');
    }
  }

  void _setupPoseDetection() {
    // Cancel any existing subscription
    _poseSubscription?.cancel();

    _poseSubscription = _poseService.poseStream.listen((poseData) {
      if (_isDisposed) return;

      if (poseData.isEmpty) {
        if (mounted) {
          setState(() {
            _currentPose = null;
          });
        }
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

      if (mounted) {
        setState(() {
          _currentPose = PoseLandmarks(mapped);
        });
      }
    });
  }

  Future<void> _startImageStream() async {
    if (_isDisposed || _isImageStreamActive) return;

    try {
      print('Starting image stream...');
      _frameCount = 0;

      await widget.cameraController.startImageStream((CameraImage image) async {
        if (_isDisposed || !_isImageStreamActive) return;

        if (!_isProcessing) {
          _isProcessing = true;
          try {
            // Process every 5th frame to reduce load
            if (_frameCount % 5 == 0) {
              await _processFrame(image);
            }
            _frameCount++;
          } finally {
            _isProcessing = false;
          }
        }
      });

      _isImageStreamActive = true;
      print('Image stream started successfully');
    } catch (e) {
      print('Error starting image stream: $e');
      _isImageStreamActive = false;
    }
  }

  Future<void> _stopImageStream() async {
    if (!_isImageStreamActive || widget.cameraController == null) return;

    try {
      print('Stopping image stream...');
      _isImageStreamActive = false;
      await widget.cameraController.stopImageStream();
      print('Image stream stopped');
    } catch (e) {
      print('Error stopping image stream: $e');
    }
  }

  @override
  void dispose() {
    print('Disposing VirtualTryOnView...');
    _isDisposed = true;

    // Cancel pose subscription
    _poseSubscription?.cancel();
    _poseSubscription = null;

    // Stop image stream
    _stopImageStream();

    // Dispose clothing image
    _clothingImage?.dispose();
    _clothingImage = null;

    super.dispose();
  }

  Future<void> _loadClothingImage() async {
    if (_isDisposed) return;

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
      if (mounted) {
        setState(() => _isLoadingImage = false);
      }
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

        if (mounted && !_isDisposed) {
          setState(() {
            _clothingImage = frameInfo.image;
            print('Network image loaded: ${_clothingImage!.width}x${_clothingImage!.height}');
          });
        }
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

      if (mounted && !_isDisposed) {
        setState(() {
          _clothingImage = frameInfo.image;
          print('Asset image loaded: ${_clothingImage!.width}x${_clothingImage!.height}');
        });
      }
    } catch (e) {
      print('Error loading asset image: $e');
      rethrow;
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isDisposed) return;

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

  Future<void> _capturePhoto() async {
    if (_isCapturing || !mounted) return;

    setState(() => _isCapturing = true);

    try {
      // Request storage permission first
      final status = await _requestStoragePermission();
      if (!status) {
        throw Exception('Storage permission denied');
      }

      // Method 1: Capture the camera feed + overlay
      await _captureWithOverlay();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Photo saved to gallery!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            action: _lastCapturedImagePath != null
                ? SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => _viewCapturedImage(),
            )
                : null,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('[CAPTURE ERROR] Error capturing photo: $e');
      print('[CAPTURE ERROR] Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Failed to save photo: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

// Replace the _captureWithOverlay method with this:
  Future<void> _captureWithOverlay() async {
    try {
      print('[OVERLAY] Starting capture with overlay...');

      // Stop image stream temporarily to take photo
      print('[OVERLAY] Stopping image stream...');
      await _stopImageStream();

      // Take the photo from camera
      print('[OVERLAY] Taking photo with camera controller...');
      final XFile photo = await widget.cameraController.takePicture();
      print('[OVERLAY] Photo taken: ${photo.path}');

      // Read the photo as bytes
      print('[OVERLAY] Reading photo bytes...');
      final Uint8List photoBytes = await photo.readAsBytes();
      print('[OVERLAY] Photo bytes length: ${photoBytes.length}');

      // Decode the photo
      img.Image? cameraImage = img.decodeImage(photoBytes);
      if (cameraImage == null) throw Exception('Failed to decode camera image');

      // Create a new image to draw on
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw the camera image
      final cameraImageUi = await _convertImageToUiImage(cameraImage);
      canvas.drawImage(cameraImageUi, Offset.zero, Paint());

      // Draw the clothing overlay if pose is detected
      if (_currentPose != null && _clothingImage != null) {
        final painter = ClothingOverlayPainter(
          pose: _currentPose,
          clothingImage: _clothingImage,
          cameraSize: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
          clothingType: widget.clothingType,
          showDebugInfo: false, // Don't show debug in captured image
          showSkeleton: false,
        );
        painter.paint(canvas, Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()));
      }

      // Convert canvas to image
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(cameraImage.width, cameraImage.height);

      // Convert to bytes and save
      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to convert image to bytes');

      final buffer = byteData.buffer.asUint8List();

      print('[OVERLAY] Getting temp directory...');
      final tempDir = await getTemporaryDirectory();
      print('[OVERLAY] Temp directory: ${tempDir.path}');

      final tryOnDir = Directory('${tempDir.path}/tryon_images');
      if (!await tryOnDir.exists()) {
        await tryOnDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempPath = '${tryOnDir.path}/tryon_$timestamp.png';
      print('[OVERLAY] Temp file path: $tempPath');

      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(buffer);

      // Save to gallery using gal
      print('[OVERLAY] Saving to gallery using gal...');
      await Gal.putImage(
        tempPath,
        album: 'SecondSight', // Optional: create a specific album
      );

      print('[OVERLAY] Successfully saved to gallery');
      _lastCapturedImagePath = tempPath;

      if (mounted) {
        setState(() {
          _recentImages.insert(0, tempFile);
          // Keep only the last 10 images
          if (_recentImages.length > 10) {
            _recentImages.removeLast();
          }
        });
      }

      // Restart image stream
      await _startImageStream();

    } catch (e) {
      print('Error in _captureWithOverlay: $e');
      // Ensure image stream is restarted even if there's an error
      await _startImageStream();
      rethrow;
    }
  }

  Future<bool> _requestStoragePermission() async {
    // Check if we have access to save to gallery
    final hasAccess = await Gal.hasAccess();

    if (!hasAccess) {
      // Request access
      final granted = await Gal.requestAccess();
      if (!granted) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Permission Required'),
              content: Text('Please enable photo library access in settings to save photos.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Gal.open(); // Opens the app settings
                  },
                  child: Text('Open Settings'),
                ),
              ],
            ),
          );
        }
        return false;
      }
    }

    return true;
  }

  Future<ui.Image> _convertImageToUiImage(img.Image image) async {
    final bytes = img.encodePng(image);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void _viewGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TryOnGalleryScreen(
          recentImages: _recentImages,
          onImageDeleted: () {
            _loadRecentImages(); // Reload images after deletion
          },
        ),
      ),
    );
  }

  void _viewCapturedImage() {
    if (_lastCapturedImagePath == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: CustomBackButton(),
            title: Text('Captured Photo'),
            backgroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(Icons.share),
                onPressed: () {
                  // Implement share functionality
                },
              ),
            ],
          ),
          backgroundColor: Colors.white,
          body: Center(
            child: Image.file(
              File(_lastCapturedImagePath!),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera preview with repaint boundary
        RepaintBoundary(
          key: _repaintBoundaryKey,
          child: Stack(
            children: [
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
                ),
              ),
            ],
          ),
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
                  'Image: ${_clothingImage != null ? "Loaded" : _isLoadingImage ? "Loading..." : "Failed"}\n'
                  'Stream: ${_isImageStreamActive ? "Active" : "Inactive"}',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),

        // Camera controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery button
                Stack(
                  children: [
                    IconButton(
                      onPressed: _viewGallery,
                      icon: Icon(Icons.photo_library_outlined),
                      iconSize: 30,
                      color: Colors.white,
                    ),
                    if (_recentImages.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${_recentImages.length}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Capture button
                GestureDetector(
                  onTap: _isCapturing ? null : _capturePhoto,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                      color: _isCapturing ? Colors.grey : Colors.white,
                    ),
                    child: _isCapturing
                        ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        strokeWidth: 3,
                      ),
                    )
                        : Icon(
                      Icons.camera,
                      color: Colors.black,
                      size: 35,
                    ),
                  ),
                ),

                // Switch camera button
                IconButton(
                  onPressed: () async {
                    // Stop stream before switching
                    await _stopImageStream();

                    // Switch camera logic here
                    // You'll need to implement camera switching in the parent widget

                    // Restart stream after switching
                    await Future.delayed(Duration(milliseconds: 500));
                    await _startImageStream();
                  },
                  icon: Icon(Icons.flip_camera_ios_outlined),
                  iconSize: 30,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


// Gallery Screen to view recent try-on photos
class TryOnGalleryScreen extends StatefulWidget {
  final List<File> recentImages;
  final VoidCallback onImageDeleted;

  const TryOnGalleryScreen({
    Key? key,
    required this.recentImages,
    required this.onImageDeleted,
  }) : super(key: key);

  @override
  _TryOnGalleryScreenState createState() => _TryOnGalleryScreenState();
}

class _TryOnGalleryScreenState extends State<TryOnGalleryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        title: Text('Recent Try-Ons', style: TextStyle(color: Colors.black)),
      ),
      body: widget.recentImages.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.white54,
            ),
            SizedBox(height: 16),
            Text(
              'No photos yet',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Take some try-on photos!',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      )
          : GridView.builder(
        padding: EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: widget.recentImages.length,
        itemBuilder: (context, index) {
          final image = widget.recentImages[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenImageView(
                    imageFile: image,
                    onDelete: () {
                      widget.onImageDeleted();
                      Navigator.pop(context);
                    },
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: FileImage(image),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Full screen image viewer
class FullScreenImageView extends StatelessWidget {
  final File imageFile;
  final VoidCallback onDelete;

  const FullScreenImageView({
    Key? key,
    required this.imageFile,
    required this.onDelete,
  }) : super(key: key);

  Future<void> _shareImage() async {
    try {
      // Use share_plus to share the image
      await Share.shareXFiles(
        [XFile(imageFile.path)],
        text: 'Check out my virtual try-on!',
      );
    } catch (e) {
      print('Error sharing image: $e');
    }
  }

  void _deleteImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Photo'),
        content: Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await imageFile.delete();
                Navigator.pop(context); // Close dialog
                onDelete(); // Call callback
              } catch (e) {
                print('Error deleting image: $e');
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: Colors.black),
            onPressed: _shareImage,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.black),
            onPressed: () => _deleteImage(context),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(
            imageFile,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}