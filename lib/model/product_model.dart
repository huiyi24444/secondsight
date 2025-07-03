import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final double price;
  final double oriPrice;
  final String condition;
  final String status;
  final int stockQuantity;
  final String description;
  final Map<String, dynamic> virtualTryOn;
  final Map<String, dynamic> measurements;
  final DocumentReference category;
  final List<String> tags;
  final List<String> images;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.oriPrice,
    required this.condition,
    required this.status,
    required this.stockQuantity,
    required this.description,
    required this.virtualTryOn,
    required this.measurements,
    required this.category,
    required this.images,
    required this.tags,
    this.createdAt,
    this.updatedAt,
  });

  String? get tryOnImageUrl {
    if (virtualTryOn.isEmpty) return null;
    return virtualTryOn['tryOnData'] as String?;
  }

  String? get tryOnType {
    return virtualTryOn['type'] as String? ?? 'upper';
  }

  bool get hasVirtualTryOn {
    return virtualTryOn.isNotEmpty &&
        virtualTryOn['tryOnData'] != null &&
        (virtualTryOn['enabled'] ?? true);
  }

  factory Product.fromDocument(Map<String, dynamic> data, String id) {
    return Product(
      id: id,
      name: data['productName'] ?? '',
      price: (data['productPrice'] as num?)?.toDouble() ?? 0.0,
      oriPrice: (data['productOriPrice'] as num?)?.toDouble() ?? 0.0,
      condition: data['productCondition'] ?? '',
      status: data['productStatus'] ?? '',
      stockQuantity: (data['stockQuantity'] as num?)?.toInt() ?? 0,
      description: data['productDesc'] ?? '',
      virtualTryOn: (data['virtualTryOn'] ?? {}) is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['virtualTryOn'])
          : {},
      measurements: (data['measurements'] ?? {}) is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['measurements'])
          : {},
      category: data['category'] as DocumentReference<Object?>,
      images: List<String>.from(data['productURL'] ?? []),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  factory Product.fromAlgolia(Map<String, dynamic> data, String id) {
    return Product(
      id: id,
      name: data['productName'] ?? '',
      price: (data['productPrice'] as num?)?.toDouble() ?? 0.0,
      oriPrice: (data['productOriPrice'] as num?)?.toDouble() ?? 0.0,
      condition: data['productCondition'] ?? '',
      status: data['productStatus'] ?? '',
      stockQuantity: (data['stockQuantity'] as num?)?.toInt() ?? 0,
      description: data['productDesc'] ?? '',
      virtualTryOn: Map<String, dynamic>.from(data['virtualTryOn'] ?? {}),
      measurements: Map<String, dynamic>.from(data['measurements'] ?? {}),
      category: FirebaseFirestore.instance.doc(data['category']),
      images: List<String>.from(data['productURL'] ?? []),
      createdAt: data['createdAt'] is int
          ? Timestamp.fromMillisecondsSinceEpoch(data['createdAt'])
          : null,
      updatedAt: data['updatedAt'] is int
          ? Timestamp.fromMillisecondsSinceEpoch(data['updatedAt'])
          : null,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }


  factory Product.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    print('Measurements from snapshot: ${data['measurements']}');
    return Product(
      id: doc.id,
      name: data['productName'] ?? '',
      price: (data['productPrice'] as num?)?.toDouble() ?? 0.0,
      oriPrice: (data['productOriPrice'] as num?)?.toDouble() ?? 0.0,
      condition: data['productCondition'] ?? '',
      status: data['productStatus'] ?? '',
      stockQuantity: (data['stockQuantity'] as num?)?.toInt() ?? 0,
      description: data['productDesc'] ?? '',
      virtualTryOn: (data['virtualTryOn'] ?? {}) is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['virtualTryOn'])
          : {},
      measurements: (data['measurements'] ?? {}) is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['measurements'])
          : {},
      category: data['category'] as DocumentReference<Object?>,
      images: List<String>.from(data['productURL'] ?? []),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }
}
