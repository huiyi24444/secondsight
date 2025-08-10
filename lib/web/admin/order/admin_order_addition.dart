
// Create Order Dialog remains the same
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
  String orderType = 'General';
  String orderStatus = 'Pending';
  final TextEditingController _noteController = TextEditingController();

  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> selectedProducts = [];
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
          'stock': doc.data()['stockQuantity'] ?? 0,
        }).toList();

        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  void _addProduct() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String? selectedProductId;
        int quantity = 1;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Product'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedProductId,
                    decoration: InputDecoration(
                      labelText: 'Select Product',
                      border: OutlineInputBorder(),
                    ),
                    items: products.map<DropdownMenuItem<String>>((product) {
                      return DropdownMenuItem<String>(
                        value: product['id'],
                        child: Text('${product['name']} - RM${product['price']}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedProductId = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    initialValue: '1',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      quantity = int.tryParse(value) ?? 1;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedProductId != null ? () {
                    final product = products.firstWhere((p) => p['id'] == selectedProductId);
                    this.setState(() {
                      selectedProducts.add({
                        'id': product['id'],
                        'name': product['name'],
                        'price': product['price'],
                        'quantity': quantity,
                        'total': product['price'] * quantity,
                      });
                    });
                    Navigator.pop(context);
                  } : null,
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
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
                  Text(
                    'Create New Order',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: 30),
              if (isLoading)
                Center(child: CircularProgressIndicator())
              else ...[
                // Order Details
                Text('Order Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                SizedBox(height: 15),
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
                  onChanged: (value) {
                    setState(() {
                      selectedCustomerId = value;
                    });
                  },
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
                        items: ['General', 'Express', 'Return'].map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            orderType = value!;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: orderStatus,
                        decoration: InputDecoration(
                          labelText: 'Order Status',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: ['Pending', 'Processing', 'Delivered', 'Cancelled'].map((status) {
                          return DropdownMenuItem(value: status, child: Text(status));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            orderStatus = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30),

                // Products Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    TextButton.icon(
                      onPressed: _addProduct,
                      icon: Icon(Icons.add),
                      label: Text('Add Product'),
                    ),
                  ],
                ),
                SizedBox(height: 15),

                Container(
                  constraints: BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: selectedProducts.isEmpty
                      ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'No products added yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    itemCount: selectedProducts.length,
                    itemBuilder: (context, index) {
                      final product = selectedProducts[index];
                      return ListTile(
                        title: Text(product['name']),
                        subtitle: Text('Qty: ${product['quantity']} × RM${product['price']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'RM${product['total'].toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  selectedProducts.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                if (selectedProducts.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Divider(),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'RM${selectedProducts.fold(0.0, (sum, product) => sum + product['total']).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 20),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Order Note (Optional)',
                    hintText: 'Add note about order',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                SizedBox(height: 30),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => CreateOrderDialog(
                            onOrderCreated: () {
                              // Call any reload or state update logic here
                              // e.g., setState(() => ...) or fetchOrders();
                            },
                          ),
                        );
                      },
                      child: const Text(
                        'Create Order',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
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