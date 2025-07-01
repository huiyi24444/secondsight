import 'package:cloud_firestore/cloud_firestore.dart';

class ReturnRequestModel {
  final String id;
  final DocumentReference orderProductID;
  final Timestamp returnDate;
  final List<String> returnImages;
  final String returnReason;
  final String returnStatus;
  final String returnComment;
  final String? rejectReason;
  final int returnPrice;

  ReturnRequestModel({
    required this.id,
    required this.orderProductID,
    required this.returnDate,
    required this.returnImages,
    required this.returnReason,
    required this.returnStatus,
    required this.returnComment,
    this.rejectReason,
    required this.returnPrice,
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
      rejectReason: data['rejectReason'],
      returnPrice: data['returnPrice'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'orderProductID': orderProductID,
      'returnDate': returnDate,
      'returnImages': returnImages,
      'returnReason': returnReason,
      'returnStatus': returnStatus,
      'returnComment': returnComment,
      'returnPrice': returnPrice,
    };

    // Only include rejectReason if it's not null, cast to Object
    if (rejectReason != null) {
      map['rejectReason'] = rejectReason as Object;
    }

    return map;
  }


}
