import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ProductImageEditor extends StatefulWidget {
  final List<String> initialImages;
  final void Function(List<String>)? onImagesChanged;

  const ProductImageEditor({
    super.key,
    required this.initialImages,
    this.onImagesChanged,
  });

  @override
  State<ProductImageEditor> createState() => _ProductImageEditorState();
}

class _ProductImageEditorState extends State<ProductImageEditor> {
  late List<String> images;
  bool isUploading = false;
  bool _isLoadingImages = true;

  @override
  void initState() {
    super.initState();
    _loadInitialImages();
  }

  Future<void> _loadInitialImages() async {
    setState(() => _isLoadingImages = true);

    // Simulate loading time for initial images
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      images = List.from(widget.initialImages);
      _isLoadingImages = false;
    });
  }

  void _removeImage(int index) {
    setState(() {
      images.removeAt(index);
    });
    widget.onImagesChanged?.call(images);
  }

  void _addImage() async {
    if (isUploading || images.length >= 5) {
      if (images.length >= 5 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 5 images allowed per product'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      isUploading = true;
    });

    try {
      String? imageUrl = await _pickImage();
      if (imageUrl != null && images.length < 5) { // Double check before adding
        setState(() {
          images.add(imageUrl);
          isUploading = false;
        });
        widget.onImagesChanged?.call(images);
      } else {
        setState(() {
          isUploading = false;
        });
      }
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _pickImage() async {
    // Assert web platform for safety
    assert(kIsWeb, 'This widget is designed for web only');

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowedExtensions: null,
        allowCompression: false, // Web handles compression differently
        withData: true, // Ensures bytes are loaded
      );

      if (result != null && result.files.single.bytes != null) {
        final fileBytes = result.files.single.bytes!;
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;

        // Validate file size (e.g., max 5MB for web)
        if (fileSize > 5 * 1024 * 1024) {
          throw Exception('File size too large. Maximum 5MB allowed.');
        }

        // Generate a unique filename
        final uniqueFileName = 'product_${DateTime.now().millisecondsSinceEpoch}_$fileName';
        final ref = FirebaseStorage.instance.ref().child('products/$uniqueFileName');

        // Upload with metadata for web optimization
        final metadata = SettableMetadata(
          contentType: _getContentType(fileName),
          cacheControl: 'max-age=31536000', // 1 year cache
        );

        final uploadTask = await ref.putData(fileBytes, metadata);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        return downloadUrl;
      }
    } catch (e) {
      print('Upload error: $e');
      rethrow;
    }

    return null;
  }

  String _getContentType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // Method to show the image viewer dialog
  void _showImageViewer(int currentIndex) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return ImageViewerDialog(
          images: images,
          initialIndex: currentIndex,
          onDelete: (int index) {
            Navigator.of(context).pop();
            _removeImage(index);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while images are being retrieved
    if (_isLoadingImages) {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF7C3AED),
              ),
              SizedBox(height: 8),
              Text(
                'Loading images...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length < 5 ? images.length + 1 : images.length,
        itemBuilder: (context, index) {
          if (index < images.length) {
            // Existing image
            return _buildImageItem(index);
          } else {
            // Add image button (only show if less than 5 images)
            return _buildAddImageButton();
          }
        },
      ),
    );
  }

  Widget _buildImageItem(int index) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _showImageViewer(index),
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            width: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
              // Add subtle hover effect
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Image.network(
                    images[index],
                    fit: BoxFit.cover,
                    width: 100,
                    height: 100,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;

                      return Container(
                        color: Colors.grey[50],
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[100],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  // Overlay to indicate clickable
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black.withOpacity(0.0),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.zoom_in,
                        color: Colors.white,
                        size: 24,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddImageButton() {
    final remainingSlots = 5 - images.length;

    return GestureDetector(
      onTap: isUploading ? null : _addImage,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
          color: isUploading ? Colors.grey[200] : Colors.grey[100],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isUploading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(
              Icons.add_a_photo,
              color: Colors.grey,
              size: 24,
            ),
            if (!isUploading) ...[
              const SizedBox(height: 4),
              Text(
                '+$remainingSlots',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Image Viewer Dialog Widget
class ImageViewerDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final Function(int index)? onDelete;

  const ImageViewerDialog({
    super.key,
    required this.images,
    required this.initialIndex,
    this.onDelete,
  });

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _previousImage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextImage() {
    if (_currentIndex < widget.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black.withOpacity(0.01),
      child: GestureDetector(
        // Make the entire background clickable to close the dialog
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Image Viewer
              Center(
                child: GestureDetector(
                  // Prevent closing when tapping on the image itself
                  onTap: _toggleControls,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemCount: widget.images.length,
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.network(
                            widget.images[index],
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;

                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                          : null,
                                      color: const Color(0xFF7C3AED),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Loading image...',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.white,
                                      size: 64,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Failed to load image',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Controls Overlay
              if (_showControls) ...[
                // Top Bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: SafeArea(
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_currentIndex + 1} / ${widget.images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (widget.onDelete != null)
                            IconButton(
                              onPressed: () {
                                _showDeleteConfirmation();
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 28,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Navigation Arrows
                if (widget.images.length > 1) ...[
                  // Left Arrow
                  if (_currentIndex > 0)
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: _previousImage,
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Right Arrow
                  if (_currentIndex < widget.images.length - 1)
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: _nextImage,
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Delete Image',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this image? This action cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDelete?.call(_currentIndex);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}