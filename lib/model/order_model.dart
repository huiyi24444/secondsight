// orders_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersModel {
  final String id;
  final String? customerId;
  final DateTime orderDate;
  final String orderStatus;
  final double totalAmount;
  final bool eligibilityForReturn;
  final String? shipmentID;
  final String payment;

  // New status tracking fields
  final DateTime? confirmedDate;     // When order was confirmed
  final DateTime? toShipDate;        // When moved to "to_ship" status
  final DateTime? toReceiveDate;     // When shipped (moved to "to_receive")
  final DateTime? completedDate;     // When delivered/completed
  final DateTime? cancelledDate;     // When cancelled
  final DateTime lastStatusUpdate;   // Most recent status change

  // Optional: Track who made the status change
  final String? lastUpdatedBy;       // Admin ID who made the change

  OrdersModel({
    required this.id,
    this.customerId,
    required this.orderDate,
    required this.orderStatus,
    required this.totalAmount,
    required this.eligibilityForReturn,
    this.shipmentID,
    this.payment = "Mastercard",
    this.confirmedDate,
    this.toShipDate,
    this.toReceiveDate,
    this.completedDate,
    this.cancelledDate,
    DateTime? lastStatusUpdate,
    this.lastUpdatedBy,
  }) : lastStatusUpdate = lastStatusUpdate ?? orderDate;

  factory OrdersModel.fromJson(Map<String, dynamic> json, String docId) {
    return OrdersModel(
      id: docId,
      customerId: json['customerId'],
      orderDate: (json['orderDate'] as Timestamp).toDate(),
      orderStatus: json['orderStatus'] ?? 'processing',
      totalAmount: double.tryParse(json['totalAmount'].toString()) ?? 0.0,
      eligibilityForReturn: json['eligibilityForReturn'] ?? false,
      shipmentID: json['shipmentID'],
      payment: json['payment'] ?? 'Mastercard',
      // Parse new date fields
      confirmedDate: json['confirmedDate'] != null
          ? (json['confirmedDate'] as Timestamp).toDate()
          : null,
      toShipDate: json['toShipDate'] != null
          ? (json['toShipDate'] as Timestamp).toDate()
          : null,
      toReceiveDate: json['toReceiveDate'] != null
          ? (json['toReceiveDate'] as Timestamp).toDate()
          : null,
      completedDate: json['completedDate'] != null
          ? (json['completedDate'] as Timestamp).toDate()
          : null,
      cancelledDate: json['cancelledDate'] != null
          ? (json['cancelledDate'] as Timestamp).toDate()
          : null,
      lastStatusUpdate: json['lastStatusUpdate'] != null
          ? (json['lastStatusUpdate'] as Timestamp).toDate()
          : (json['orderDate'] as Timestamp).toDate(),
      lastUpdatedBy: json['lastUpdatedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'orderDate': Timestamp.fromDate(orderDate),
      'orderStatus': orderStatus,
      'totalAmount': totalAmount,
      'eligibilityForReturn': eligibilityForReturn,
      'shipmentID': shipmentID,
      'payment': payment,
      // Include new date fields
      'confirmedDate': confirmedDate != null ? Timestamp.fromDate(confirmedDate!) : null,
      'toShipDate': toShipDate != null ? Timestamp.fromDate(toShipDate!) : null,
      'toReceiveDate': toReceiveDate != null ? Timestamp.fromDate(toReceiveDate!) : null,
      'completedDate': completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'cancelledDate': cancelledDate != null ? Timestamp.fromDate(cancelledDate!) : null,
      'lastStatusUpdate': Timestamp.fromDate(lastStatusUpdate),
      'lastUpdatedBy': lastUpdatedBy,
    };
  }

  OrdersModel copyWith({
    String? id,
    String? customerId,
    DateTime? orderDate,
    String? orderStatus,
    double? totalAmount,
    bool? eligibilityForReturn,
    String? shipmentID,
    String? payment,
    DateTime? confirmedDate,
    DateTime? toShipDate,
    DateTime? toReceiveDate,
    DateTime? completedDate,
    DateTime? cancelledDate,
    DateTime? lastStatusUpdate,
    String? lastUpdatedBy,
  }) {
    return OrdersModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      orderDate: orderDate ?? this.orderDate,
      orderStatus: orderStatus ?? this.orderStatus,
      totalAmount: totalAmount ?? this.totalAmount,
      eligibilityForReturn: eligibilityForReturn ?? this.eligibilityForReturn,
      shipmentID: shipmentID ?? this.shipmentID,
      payment: payment ?? this.payment,
      confirmedDate: confirmedDate ?? this.confirmedDate,
      toShipDate: toShipDate ?? this.toShipDate,
      toReceiveDate: toReceiveDate ?? this.toReceiveDate,
      completedDate: completedDate ?? this.completedDate,
      cancelledDate: cancelledDate ?? this.cancelledDate,
      lastStatusUpdate: lastStatusUpdate ?? this.lastStatusUpdate,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
    );
  }

  String get shortOrderId =>
      (id.length >= 6 ? id.substring(0, 6) : id).toUpperCase();

  // Helper methods for status duration calculations
  Duration? get processingDuration {
    if (toShipDate != null) {
      return toShipDate!.difference(orderDate);
    }
    return null;
  }

  Duration? get shippingDuration {
    if (toShipDate != null && toReceiveDate != null) {
      return toReceiveDate!.difference(toShipDate!);
    }
    return null;
  }

  Duration? get deliveryDuration {
    if (toReceiveDate != null && completedDate != null) {
      return completedDate!.difference(toReceiveDate!);
    }
    return null;
  }

  Duration? get totalFulfillmentDuration {
    if (completedDate != null) {
      return completedDate!.difference(orderDate);
    }
    return null;
  }

  // Check if order is overdue based on status
  bool isOverdueForShipping({int maxDaysToShip = 2}) {
    if (orderStatus == 'to_ship' && toShipDate == null) {
      // Order is in to_ship but we don't have the date it entered this status
      // Fall back to order date
      return DateTime.now().difference(orderDate).inDays > maxDaysToShip;
    } else if (orderStatus == 'to_ship' && toShipDate != null) {
      return DateTime.now().difference(toShipDate!).inDays > maxDaysToShip;
    }
    return false;
  }
}