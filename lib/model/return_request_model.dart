import 'package:cloud_firestore/cloud_firestore.dart';

class ReturnRequestModel {
  final String id;
  final DocumentReference orderProductID;
  final Timestamp returnDate;
  final List<String> returnImages;
  final String returnReason;
  final String returnStatus;
  final String returnComment;

  ReturnRequestModel({
    required this.id,
    required this.orderProductID,
    required this.returnDate,
    required this.returnImages,
    required this.returnReason,
    required this.returnStatus,
    required this.returnComment,
  });

  factory ReturnRequestModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ReturnRequestModel(
      id: doc.id,
      orderProductID: data['orderProductID'] as DocumentReference,
      returnDate: data['returnDate'] as Timestamp,
      returnImages: List<String>.from(data['returnImages'] ?? []),
      returnReason: data['returnReason'] as String,
      returnStatus: data['returnStatus'] as String,
      returnComment: data['returnComment'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderProductID': orderProductID,
      'returnDate': returnDate,
      'returnImages': returnImages,
      'returnReason': returnReason,
      'returnStatus': returnStatus,
      'returnComment': returnComment,
    };
  }
}
