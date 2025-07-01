import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateOrderDialog extends StatefulWidget {
  final Function onOrderCreated;

  const CreateOrderDialog({Key? key, required this.onOrderCreated}) : super(key: key);

  @override
  State<CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _CreateOrderDialogState extends State<CreateOrderDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String? selectedCustomerId;
  String? selectedProductId;
  String orderType = 'General';
  String orderStatus = 'Pending';
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _noteController = TextEditingController();

  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> products = [];
  Map<String, dynamic> selectedProductDetails = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final customersSnapshot = await _firestore.collection('users').get();
      final productsSnapshot = await _firestore.collection('products').get();

      setState(() {
        customers = customersSnapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc.data()['name'] ?? 'Unknown',
          'email': doc.data()['email'] ?? '',
        }).toList();

        products = productsSnapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc.data()['productName'] ?? 'Unknown Product',
          'price': doc.data()['price'] ?? 0.0,
          'sku': doc.data()['sku'] ?? '',
        }).toList();

        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final quantity = int.parse(_quantityController.text);
      final total = selectedProductDetails['price'] * quantity;

      final orderData = {
        'orderId': 'ORD${DateTime.now().millisecondsSinceEpoch}'.substring(0, 10),
        'customerId': selectedCustomerId,
        'items': [{
          'productId': selectedProductId,
          'productName': selectedProductDetails['name'],
          'quantity': quantity,
          'price': selectedProductDetails['price'],
        }],
        'total': total,
        'orderStatus': orderStatus.toLowerCase(),
        'orderType': orderType,
        'note': _noteController.text,
        'date': DateTime.now().millisecondsSinceEpoch,
        'paymentMethod': 'Mastercard',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(selectedCustomerId)
          .collection('order')
          .add(orderData);

      Navigator.pop(context);
      widget.onOrderCreated();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: EdgeInsets.all(30),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Create New Order', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close)),
                ],
              ),
              SizedBox(height: 30),
              if (isLoading)
                Center(child: CircularProgressIndicator())
              else ...[
                DropdownButtonFormField<String>(
                  value: selectedCustomerId,
                  decoration: InputDecoration(
                    labelText: 'Select Customer',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: customers.map<DropdownMenuItem<String>>((customer) {
                    return DropdownMenuItem<String>(
                      value: customer['id'],
                      child: Text('${customer['name']} (${customer['email']})'),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedCustomerId = value),
                  validator: (value) => value == null ? 'Please select a customer' : null,
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: orderType,
                        decoration: InputDecoration(
                          labelText: 'Order Type',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: ['General', 'Express', 'Return']
                            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                            .toList(),
                        onChanged: (value) => setState(() => orderType = value!),
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: TextFormField(
                        initialValue: DateTime.now().toString().split(' ')[0],
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Order Date',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Order Note',
                    hintText: 'Add note about order',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                SizedBox(height: 30),
                DropdownButtonFormField<String>(
                  value: selectedProductId,
                  decoration: InputDecoration(
                    labelText: 'Search product name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.search),
                  ),
                  items: products.map<DropdownMenuItem<String>>((product) {
                    return DropdownMenuItem<String>(
                      value: product['id'],
                      child: Text('${product['name']} - \$${product['price']}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedProductId = value;
                      selectedProductDetails = products.firstWhere((p) => p['id'] == value);
                    });
                  },
                  validator: (value) => value == null ? 'Please select a product' : null,
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter quantity';
                    if (int.tryParse(value) == null) return 'Please enter a valid number';
                    return null;
                  },
                ),
                SizedBox(height: 30),
                DropdownButtonFormField<String>(
                  value: orderStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: ['Pending', 'Processing', 'Delivered', 'Cancelled']
                      .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                      .toList(),
                  onChanged: (value) => setState(() => orderStatus = value!),
                ),
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _createOrder,
                      child: Text('Create Order'),
                      style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C3AED)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
