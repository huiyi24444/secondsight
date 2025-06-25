import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:secondsight/view/widgets/custom_back_button.dart';

import 'add_address_view.dart';
import 'edit_address_view.dart';

class AddressListView extends StatelessWidget {
  final String userId;

  const AddressListView({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        leading: const CustomBackButton(), // Use your custom back button here
        title: const Text("Address"),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('address')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();
          final addresses = snapshot.data!.docs;

          return Padding(
            padding: const EdgeInsets.only(top: 16, left:7, right:7, bottom: 5), // 👈 Adds spacing below AppBar
            child: ListView.builder(
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                final doc = addresses[index];
                final data = doc.data() as Map<String, dynamic>;
                final address =
                    "${data['streetone']}, ${data['streettwo']}, ${data['city']}, ${data['state']} ${data['zipCode']}";

                return Card(
                  color: const Color(0xFFF4F4F4),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(address, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditAddressView(
                              userId: userId,
                              addressId: doc.id,
                              initialData: data,
                            ),
                          ),
                        );
                      },
                      child: const Text("Edit", style: TextStyle(color: Colors.purple)),
                    ),
                  ),
                );
              },
            ),
          );

        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: 	Color(0xFFF4F4F4),
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddAddressView(userId: userId),
            ),
          );
        },
      ),
    );
  }
}
