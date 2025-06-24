import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String catName;
  final String catURL;

  Category({required this.id, required this.catName, required this.catURL});

  factory Category.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id,
      catName: data['catName'],
      catURL: data['catURL'],
    );
  }
}

