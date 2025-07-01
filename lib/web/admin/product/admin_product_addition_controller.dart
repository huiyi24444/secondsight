// controllers/product_addition_controller.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:html' as html;

import '../../../model/category_model.dart';

class ProductAdditionController {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  ProductAdditionController({
    required this.firestore,
    required this.storage,
  });

  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  final originalPriceController = TextEditingController();
  final heightController = TextEditingController();
  final lengthController = TextEditingController();
  final widthController = TextEditingController();
  String? selectedSize;
  final quantityController = TextEditingController();

  String? selectedStatus = 'available';
  String selectedCondition = 'good';
  List<String> selectedTags = [];
  List<html.File> selectedImages = [];
  List<String> uploadedImageUrls = [];
  List<Category> categories = [];
  Category? selectedCategory;

  bool virtualTryOnEnabled = false;
  String selectedTryOnType = 'upper';
  html.File? virtualTryOnImage;
  String? uploadedTryOnImageUrl;

  final conditions = ['good', 'like_new', 'excellent', 'fair'];
  final statuses = ['available', 'sold', 'inactive'];
  final availableTags = ['vintage', 'designer', 'limited_edition', 'rare', 'trending'];
  final tryOnTypes = ['upper', 'bottom'];

  bool isLoading = false;
  bool isCategoriesLoading = true;

  Future<void> loadCategories(VoidCallback onUpdate) async {
    try {
      isCategoriesLoading = true;
      onUpdate();

      final snapshot = await firestore.collection('category').get();
      categories = snapshot.docs.map((doc) => Category.fromDocument(doc)).toList();
    } catch (e) {
      print('Error loading categories: \$e');
    } finally {
      isCategoriesLoading = false;
      onUpdate();
    }
  }

  Future<void> pickImages(VoidCallback onUpdate) async {
    if (selectedImages.length >= 5) return;

    final input = html.FileUploadInputElement()..accept = 'image/*'..multiple = true;
    input.click();
    await input.onChange.first;

    if (input.files != null) {
      final files = input.files!;
      final remainingSlots = 5 - selectedImages.length;
      final filesToAdd = files.take(remainingSlots).toList();
      selectedImages.addAll(filesToAdd);
      onUpdate();
    }
  }

  Future<void> pickVirtualTryOnImage(VoidCallback onUpdate) async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    await input.onChange.first;

    if (input.files != null && input.files!.isNotEmpty) {
      virtualTryOnImage = input.files!.first;
      onUpdate();
    }
  }

  Future<List<String>> uploadImages() async {
    List<String> urls = [];
    for (var file in selectedImages) {
      try {
        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        await reader.onLoad.first;

        final String dataUrl = reader.result as String;
        final String base64 = dataUrl.split(',')[1];

        final ref = storage.ref().child('products/\${DateTime.now().millisecondsSinceEpoch}_\${file.name}');
        await ref.putString(base64, format: PutStringFormat.base64);
        final url = await ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        print('Error uploading image: \$e');
      }
    }
    return urls;
  }

  Future<String?> uploadVirtualTryOnImage() async {
    if (virtualTryOnImage == null) return null;

    try {
      final reader = html.FileReader();
      reader.readAsDataUrl(virtualTryOnImage!);
      await reader.onLoad.first;

      final String dataUrl = reader.result as String;
      final String base64 = dataUrl.split(',')[1];

      final ref = storage.ref().child('virtual_try_on/\${DateTime.now().millisecondsSinceEpoch}_\${virtualTryOnImage!.name}');
      await ref.putString(base64, format: PutStringFormat.base64);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading virtual try-on image: \$e');
      return null;
    }
  }

  Future<void> saveProduct(BuildContext context, VoidCallback onUpdate) async {
    if (!formKey.currentState!.validate()) return;

    isLoading = true;
    onUpdate();

    try {
      uploadedImageUrls = await uploadImages();

      if (virtualTryOnEnabled && virtualTryOnImage != null) {
        uploadedTryOnImageUrl = await uploadVirtualTryOnImage();
      }

      final price = double.parse(priceController.text);
      final originalPrice = originalPriceController.text.isNotEmpty
          ? double.parse(originalPriceController.text)
          : price;


      final measurements = {
        'productHeight': heightController.text.isNotEmpty ? double.parse(heightController.text) : null,
        'productLength': lengthController.text.isNotEmpty ? double.parse(lengthController.text) : null,
        'productWidth': widthController.text.isNotEmpty ? double.parse(widthController.text) : null,
        'productSize': selectedSize,

      };

      Map<String, dynamic>? virtualTryOnData;
      if (virtualTryOnEnabled && uploadedTryOnImageUrl != null) {
        virtualTryOnData = {
          'enabled': true,
          'tryOnData': uploadedTryOnImageUrl,
          'type': selectedTryOnType,
        };
      }

      final productData = {
        'productName': nameController.text,
        'productDesc': descriptionController.text,
        'productPrice': price,
        'productOriPrice': originalPrice,
        'category': FirebaseFirestore.instance.collection('category').doc(selectedCategory?.id),
        'productCondition': selectedCondition,
        'productStatus': selectedStatus,
        'tags': selectedTags,
        'productURL': uploadedImageUrls,
        'measurements': measurements,
        'stockQuantity': int.parse(quantityController.text),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt':  FieldValue.serverTimestamp(),
      };

      if (virtualTryOnData != null) {
        productData['virtualTryOn'] = virtualTryOnData;
      }

      await firestore.collection('products').add(productData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product added successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding product: \$e')),
      );
    } finally {
      isLoading = false;
      onUpdate();
    }
  }
}
