import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:secondsight/view/widgets/custom_back_button.dart';
import '../../../model/product_model.dart';
import '../widgets/virtual_try_on_view.dart';

class VirtualTryOnScreen extends StatefulWidget {
  final String productId;
  final Product? product;


  const VirtualTryOnScreen({
    Key? key,
    required this.productId,
    this.product,
  }) : super(key: key);

  @override
  _VirtualTryOnScreenState createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  Product? _product;
  bool _isLoading = true;
  bool _hasPermission = false;
  String _errorMessage = '';

  bool _showGuide = true;  // Show guide initially
  bool _hasSeenGuide = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    print('[DEBUG] VirtualTryOnScreen initialized.');
    print('[DEBUG] _showGuide: $_showGuide, _hasSeenGuide: $_hasSeenGuide');

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Load product first
    if (widget.product != null) {
      _product = widget.product;
    } else {
      _loadProduct();
    }

    // Then initialize camera
    await _initializeCamera();
    setState(() => _isLoading = false);


    // Show guide dialog after everything is loaded
    if (_showGuide && !_hasSeenGuide && mounted) {
      // Add a small delay to ensure the camera preview is ready
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          _showGuideDialog();
        }
      });
    }
  }

  // Method to dismiss guide
  void _dismissGuide() {
    setState(() {
      _showGuide = false;
      _hasSeenGuide = true;
    });
  }

  Future<void> _loadProduct() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .get();
      if (doc.exists) {
        _product = Product.fromDocument(
          doc.data() as Map<String, dynamic>,
          widget.productId,
        );
      }
    } catch (e) {
      print('Error loading product: $e');
      _errorMessage = 'Failed to load product';
    }
  }

  // Show guide dialog over camera
  void _showGuideDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lottie Animation
                SizedBox(
                  height: 220,
                  width: 220,
                  child: Lottie.asset(
                    'assets/animations/vto_icon.json',
                    height: 220,
                    width: 220,
                    fit: BoxFit.contain,
                  ),
                ),

                SizedBox(height: 3),

                // Guide Text
                Text(
                  'Place your phone upright at a 90° angle\nand position it slightly farther away for the best experience.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                SizedBox(height: 24),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      _dismissGuide(); // Update state
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF8E6CEF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Got it!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _initializeCamera() async {
    try {
      // Check and request camera permission
      final status = await Permission.camera.status;
      if (status.isDenied) {
        final result = await Permission.camera.request();
        if (!result.isGranted) {
          setState(() {
            _hasPermission = false;
            _errorMessage = 'Camera permission is required for virtual try-on';
          });
          return;
        }
      } else if (status.isPermanentlyDenied) {
        setState(() {
          _hasPermission = false;
          _errorMessage = 'Camera permission is permanently denied. Please enable it in settings.';
        });
        return;
      }

      _hasPermission = true;

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras available on this device';
        });
        return;
      }

      // Find front camera
      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Initialize camera controller
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // Ensure consistent format
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }

      print('Camera initialized successfully');
    } catch (e) {
      print('Error initializing camera: $e');
      setState(() {
        _errorMessage = 'Failed to initialize camera: ${e.toString()}';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // App is inactive (e.g., incoming call)
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // App is resumed, reinitialize camera
      _initializeCamera();
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initializeCamera();
    } else if (status.isPermanentlyDenied) {
      // Show dialog to open settings
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Camera Permission Required'),
          content: Text(
            'Virtual try-on requires camera access. Please enable camera permission in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    // Show loading screen
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.black),
              SizedBox(height: 16),
              Text(
                'Initializing...',
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
        ),
      );
    }

    // Show error screen
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Virtual Try-On', style: TextStyle(color: Colors.black)),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.black,
                ),
                SizedBox(height: 16),
                Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.black, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                if (!_hasPermission)
                  ElevatedButton(
                    onPressed: _requestCameraPermission,
                    child: Text('Grant Camera Permission'),
                  ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show product not found
    if (_product == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: CustomBackButton(),
          title: Text('Virtual Try-On', style: TextStyle(color: Colors.black)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.black),
              SizedBox(height: 16),
              Text(
                'Product not found',
                style: TextStyle(color: Colors.black, fontSize: 18),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Show no try-on image available
    final tryOnImageUrl = _product!.tryOnImageUrl;
    if (tryOnImageUrl == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: CustomBackButton(),
          title: Text('Virtual Try-On', style: TextStyle(color: Colors.black)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, size: 64, color: Colors.black),
              SizedBox(height: 16),
              Text(
                'No image available for virtual try-on',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Show camera not initialized
    if (!_isCameraInitialized || _cameraController == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.black),
              SizedBox(height: 16),
              Text(
                'Initializing camera...',
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
        ),
      );
    }

    // Main virtual try-on screen
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: CustomBackButton(),
        title: Text(
          'Try On: ${_product!.name}',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.black),
            onPressed: _showProductInfo,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Virtual Try-On View
          VirtualTryOnView(
            clothingImageUrl: tryOnImageUrl,
            cameraSize: _cameraController!.value.previewSize!,
            cameraController: _cameraController!,
            clothingType: _product?.tryOnType ?? 'upper',
          ),
        ],
      ),
    );
  }

  void _showProductInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _product!.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'RM ${_product!.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'RM ${_product!.oriPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text('Condition: ${_product!.condition}'),
            Text('Size: ${_product!.productSize ?? 'N/A'}'),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

