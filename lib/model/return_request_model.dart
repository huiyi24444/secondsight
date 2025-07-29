import 'package:cloud_firestore/cloud_firestore.dart';

class ReturnRequestModel {
  final String id;
  final String orderProductID;
  final String orderID;
  final String userID;
  final Timestamp returnDate;
  final List<String> returnImages;
  final String returnReason;
  final String returnStatus;
  final String returnComment;
  final String? rejectReason;
  final double returnPrice;

  final int returnQuantity;      // From orderProduct
  final String productName;      // From product
  final String productImageUrl;  // From product (just the main image)

  final Timestamp? pendingDate;
  final Timestamp? approvedDate;
  final Timestamp? rejectedDate;
  final Timestamp? completedDate;
  final Timestamp? pendinginspectionDate;
  final Timestamp? completedinsepectionDate;
  final Timestamp? cancelledDate;

  ReturnRequestModel({
    required this.id,
    required this.orderProductID,
    required this.orderID,
    required this.userID,
    required this.returnDate,
    required this.returnImages,
    required this.returnReason,
    required this.returnStatus,
    required this.returnComment,
    this.rejectReason,
    required this.returnPrice,

    required this.returnQuantity,
    required this.productName,
    required this.productImageUrl,

    this.pendingDate,
    this.approvedDate,
    this.rejectedDate,
    this.completedDate,
    this.pendinginspectionDate,
    this.completedinsepectionDate,
    this.cancelledDate,
  });

  factory ReturnRequestModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ReturnRequestModel(
      id: doc.id,
      orderProductID: data['orderProductID'] as String,
      orderID: data['orderID'] as String,
      userID: data['userID'] as String,
      returnDate: data['returnDate'] as Timestamp,
      returnImages: List<String>.from(data['returnImages'] ?? []),
      returnReason: data['returnReason'] as String,
      returnStatus: data['returnStatus'] as String,
      returnComment: data['returnComment'] as String,
      rejectReason: data['rejectReason'],
      returnPrice: (data['returnPrice'] as num).toDouble(),
      returnQuantity: data['returnQuantity'] as int,
      productName: data['productName'] as String,
      productImageUrl: data['productImageUrl'] as String,
      pendingDate: data['pendingDate'] as Timestamp,
      approvedDate: data['approvedDate'] as Timestamp,
      rejectedDate: data['rejectedDate'] as Timestamp,
      completedDate: data['completedDate'] as Timestamp,
      pendinginspectionDate: data['pendinginspectionDate'] as Timestamp,
      completedinsepectionDate: data['completedinsepectionDate'] as Timestamp,
      cancelledDate: data['cancelledDate'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'orderProductID': orderProductID,
      'orderID': orderID,
      'userID': userID,
      'returnDate': returnDate,
      'returnImages': returnImages,
      'returnReason': returnReason,
      'returnStatus': returnStatus,
      'returnComment': returnComment,
      'returnPrice': returnPrice,
      'returnQuantity': returnQuantity,
      'productName': productName,
      'productImageUrl': productImageUrl,
      'pendingDate': pendingDate,
      'approvedDate': approvedDate,
      'rejectedDate': rejectedDate,
      'completedDate': completedDate,
      'pendinginspectionDate': pendinginspectionDate,
      'completedinsepectionDate': completedinsepectionDate,
      'cancelledDate': cancelledDate,
    };

    // Only include rejectReason if it's not null, cast to Object
    if (rejectReason != null) {
      map['rejectReason'] = rejectReason as Object;
    }

    return map;
  }


}
