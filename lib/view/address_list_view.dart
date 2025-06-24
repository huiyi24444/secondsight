import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'add_address_view.dart';
import 'edit_address_view.dart';

class AddressListView extends StatelessWidget {
  final String userId;

  const AddressListView({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Address")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('address')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();
          final addresses = snapshot.data!.docs;

          return ListView.builder(
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final doc = addresses[index];
              final data = doc.data() as Map<String, dynamic>;
              final address =
                  "${data['streetone']}, ${data['streettwo']}, ${data['city']}, ${data['state']} ${data['zipCode']}";

              return Card(
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purple,
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
