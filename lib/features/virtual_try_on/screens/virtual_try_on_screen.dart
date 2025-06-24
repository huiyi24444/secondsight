import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../model/product_model.dart';
import '../widgets/virtual_try_on_view.dart';

class VirtualTryOnScreen extends StatefulWidget {
  final String productId;
  final Product? product; // Optional - can be passed to avoid re-fetching

  const VirtualTryOnScreen({
    Key? key,
    required this.productId,
    this.product,
  }) : super(key: key);

  @override
  _VirtualTryOnScreenState createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  Product? _product;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    // Use passed product or load from Firebase
    if (widget.product != null) {
      _product = widget.product;
      _isLoading = false;
    } else {
      _loadProduct();
    }
  }

  Future<void> _loadProduct() async {
    // Only load if product wasn't passed
    if (widget.product == null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .get();

        if (doc.exists) {
          setState(() {
            _product = Product.fromDocument(
                doc.data() as Map<String, dynamic>,
                widget.productId
            );
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading product: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_isCameraInitialized || _product == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(_isLoading ? 'Loading product...' : 'Initializing camera...'),
            ],
          ),
        ),
      );
    }

    final tryOnImageUrl = _product!.tryOnImageUrl;
    if (tryOnImageUrl == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Virtual Try-On')),
        body: Center(
          child: Text('No image available for virtual try-on'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Try On: ${_product!.name}'),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () => _showProductInfo(),
          ),
        ],
      ),
      body: Stack(
        children: [
          CameraPreview(_cameraController!),
          VirtualTryOnView(
            clothingImageUrl: tryOnImageUrl,
            cameraSize: _cameraController!.value.previewSize!,
            cameraController: _cameraController!,
            clothingType: _product?.tryOnType ?? 'upper',

          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(Icons.photo_camera, color: Colors.white),
                    onPressed: () {
                      // Take photo logic
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Add to cart logic
                    },
                    child: Text('Add to Bag'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProductInfo() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
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
            Text('Size: ${_product!.measurements['productSize'] ?? 'N/A'}'),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Go back to product details
                },
                child: Text('View Full Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}