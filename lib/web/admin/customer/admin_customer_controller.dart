// lib/view/admin/controller/customer_management_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../model/user_model.dart';
import 'admin_customer_addition.dart';
import 'admin_customer_details.dart';

class CustomerManagementController {
  final FirebaseFirestore firestore;

  CustomerManagementController({required this.firestore});

  Future<List<CustomerModel>> loadCustomers() async {
    final customersSnapshot = await firestore.collection('users').get();

    Map<String, Map<String, dynamic>> customerOrderStats = {};

    for (var customerDoc in customersSnapshot.docs) {
      final customerId = customerDoc.id;
      final orderCollection = firestore.collection('users').doc(customerId).collection('Order');
      final orderSnapshot = await orderCollection.get();

      if (orderSnapshot.docs.isNotEmpty) {
        for (var orderDoc in orderSnapshot.docs) {
          final data = orderDoc.data();

          customerOrderStats[customerId] ??= {
            'orderCount': 0,
            'totalSpent': 0.0,
            'lastOrderDate': 0,
          };

          customerOrderStats[customerId]!['orderCount']++;
          customerOrderStats[customerId]!['totalSpent'] += data['total'] ?? 0.0;

          final orderDate = data['date'] ?? 0;
          if (orderDate > customerOrderStats[customerId]!['lastOrderDate']) {
            customerOrderStats[customerId]!['lastOrderDate'] = orderDate;
          }
        }
      }
    }

    List<CustomerModel> loadedCustomers = [];

    for (var doc in customersSnapshot.docs) {
      final data = doc.data();
      final stats = customerOrderStats[doc.id] ?? {
        'orderCount': 0,
        'totalSpent': 0.0,
        'lastOrderDate': 0,
      };

      final customer = CustomerModel.fromJson(data, doc.id);
      loadedCustomers.add(customer);
    }

    return loadedCustomers;
  }

  void showAddCustomerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddCustomerDialog(onCustomerAdded: loadCustomers);
      },
    );
  }

  void showCustomerDetailsPage(BuildContext context, CustomerModel customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailsPage(userId: customer.id),
      ),
    );
  }

}
