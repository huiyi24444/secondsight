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

  @override
  void initState() {
    super.initState();
    images = List.from(widget.initialImages);
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

  @override
  Widget build(BuildContext context) {
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
        Container(
          margin: const EdgeInsets.only(right: 10),
          width: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              images[index],
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(),
                );
              },
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.grey,
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

