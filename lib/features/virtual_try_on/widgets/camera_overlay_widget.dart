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

class cameraOverlayWidget extends StatefulWidget {
  final String clothingImageUrl;
  final Size cameraSize;
  final CameraController cameraController;
  final String clothingType;

  const cameraOverlayWidget({
    Key? key,
    required this.clothingImageUrl,
    required this.cameraSize,
    required this.cameraController,
    this.clothingType = 'upper',
  }) : super(key: key);

  @override
  _cameraOverlayWidgetState createState() => _cameraOverlayWidgetState();
}

class _cameraOverlayWidgetState extends State<cameraOverlayWidget> with TickerProviderStateMixin {
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

  // Timer-related variables
  Timer? _captureTimer;
  int _timerDuration = 3; // Default 3 seconds
  int _remainingTime = 0;
  bool _isTimerActive = false;
  bool _showTimerSettings = false;

  // Animation controllers for timer
  late AnimationController _timerAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _timerAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _timerAnimationController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _timerAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _timerAnimationController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    _initializeVirtualTryOn();
    _loadRecentImages();
  }

  Future<void> _initializeVirtualTryOn() async {
    await _loadClothingImage();
    _setupPoseDetection();
    await Future.delayed(Duration(milliseconds: 1000));
    await _startImageStream();
  }

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
    } catch (e) {
      _isImageStreamActive = false;
    }
  }

  Future<void> _stopImageStream() async {
    if (!_isImageStreamActive || widget.cameraController == null) return;

    try {
      _isImageStreamActive = false;
      await widget.cameraController.stopImageStream();
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _isDisposed = true;


    // Cancel timer
    _captureTimer?.cancel();

    // Dispose animation controllers
    _timerAnimationController.dispose();
    _pulseAnimationController.dispose();

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

  void _showTimerOptions() {
    setState(() {
      _showTimerSettings = !_showTimerSettings;
    });
  }

  void _setTimerDuration(int seconds) {
    setState(() {
      _timerDuration = seconds;
      _showTimerSettings = false;
    });
  }

  void _startTimer() {
    if (_isTimerActive || _isCapturing) return;

    setState(() {
      _isTimerActive = true;
      _remainingTime = _timerDuration;
    });

    // Start countdown
    _captureTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingTime--;
      });

      // Play animation for each countdown
      _timerAnimationController.reset();
      _timerAnimationController.forward();

      // Vibrate on each countdown
      HapticFeedback.lightImpact();

      if (_remainingTime <= 0) {
        timer.cancel();
        setState(() {
          _isTimerActive = false;
        });
        // Capture photo after timer ends
        _capturePhoto();
      }
    });
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
          });
        }
      } else {
        throw Exception('Failed to load image: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _loadAssetImage() async {
    try {
      final ByteData data = await rootBundle.load(widget.clothingImageUrl);
      final Uint8List bytes = data.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();

      if (mounted && !_isDisposed) {
        setState(() {
          _clothingImage = frameInfo.image;
        });
      }
    } catch (e) {
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
      final status = await _requestStoragePermission();
      if (!status) {
        throw Exception('Storage permission denied');
      }

      await _captureWithOverlay();

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

  Future<void> _captureWithOverlay() async {
    try {
      await _stopImageStream();
      final XFile photo = await widget.cameraController.takePicture();
      final Uint8List photoBytes = await photo.readAsBytes();
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
      final tempDir = await getTemporaryDirectory();
      final tryOnDir = Directory('${tempDir.path}/tryon_images');
      if (!await tryOnDir.exists()) {
        await tryOnDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempPath = '${tryOnDir.path}/tryon_$timestamp.png';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(buffer);

      await Gal.putImage(
        tempPath,
        album: 'SecondSight',
      );
      _lastCapturedImagePath = tempPath;

      if (mounted) {
        setState(() {
          _recentImages.insert(0, tempFile);
          if (_recentImages.length > 10) {
            _recentImages.removeLast();
          }
        });
      }
      await _startImageStream();

    } catch (e) {
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
    return Column(
      children: [
        // Camera preview area with overlays
        Expanded(
          child: Stack(
            children: [
              // Camera
              CameraPreview(widget.cameraController),

              // Clothing overlay
              Positioned.fill(
                child: ClipRect(
                  child: CustomPaint(
                    painter: ClothingOverlayPainter(
                      pose: _currentPose,
                      clothingImage: _clothingImage,
                      cameraSize: widget.cameraSize,
                      clothingType: widget.clothingType,
                    ),
                  ),
                ),
              ),

              // Loading indicator
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
            ],
          ),
        ),

        // Camera controls (completely separate section below)
        Container(
          height: 235, // fixed height for controls
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white, // or gradient if you want
          ),
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // Timer Settings UI (show when _showTimerSettings is true)
              if (_showTimerSettings)
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Set Timer Duration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _timerOptionButton(0),
                          _timerOptionButton(3),
                          _timerOptionButton(5),
                          _timerOptionButton(10),
                        ],
                      ),
                    ],
                  ),
                ),

              // Timer Countdown Display (show when timer is active)
              if (_isTimerActive)
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: _timerAnimation,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '$_remainingTime',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Example control buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery button
                  IconButton(
                    onPressed: _viewGallery,
                    icon: Stack(
                      children: [
                        Icon(Icons.photo_library_outlined, size: 30),
                        if (_recentImages.isNotEmpty)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${_recentImages.length}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Capture button - THIS IS THE KEY FIX
                  GestureDetector(
                    onTap: _isCapturing || _isTimerActive
                        ? null
                        : () {
                      // Check if timer is set and greater than 0
                      if (_timerDuration > 0 && !_isTimerActive) {
                        _startTimer(); // Start timer countdown
                      } else {
                        _capturePhoto(); // Capture immediately
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _pulseAnimationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isCapturing ? _pulseAnimation.value : 1.0,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isCapturing
                                  ? Colors.red
                                  : (_isTimerActive ? Colors.orange : Colors.black),
                              boxShadow: [
                                if (_isCapturing || _isTimerActive)
                                  BoxShadow(
                                    color: (_isCapturing ? Colors.red : Colors.orange)
                                        .withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child: Icon(
                              _isCapturing
                                  ? Icons.camera_alt
                                  : (_isTimerActive ? Icons.timer : Icons.camera),
                              color: Colors.white,
                              size: 35,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Timer button
                  GestureDetector(
                    onTap: _isCapturing ? null : _showTimerOptions,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _showTimerSettings
                            ? Color(0xFF8E6CEF).withOpacity(0.2)
                            : Colors.transparent,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer,
                            size: 30,
                            color: _showTimerSettings
                                ? Color(0xFF8E6CEF)
                                : Colors.black,
                          ),
                          if (_timerDuration > 0)
                            Text(
                              '${_timerDuration}s',
                              style: TextStyle(
                                fontSize: 10,
                                color: _showTimerSettings
                                    ? Color(0xFF8E6CEF)
                                    : Colors.black,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Also, add this method to allow disabling timer (set to 0)
  Widget _timerOptionButton(int seconds) {
    final isSelected = _timerDuration == seconds;
    return GestureDetector(
      onTap: () => _setTimerDuration(seconds),
      child: Container(
        width: 60,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF8E6CEF) : Colors.white,
          border: Border.all(
            color: isSelected ? Color(0xFF8E6CEF) : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            seconds == 0 ? 'Off' : '${seconds}s',
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
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