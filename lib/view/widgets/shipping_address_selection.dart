import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShippingAddressSelection extends StatelessWidget {
  final Function(String) onAddressSelected;

  const ShippingAddressSelection({required this.onAddressSelected, Key? key}) : super(key: key);

  // Fetch and format addresses
  Future<List<String>> _fetchFormattedAddresses() async {
    const userId = 'Wra7olVmUb6hbOxDPdOD'; // Hardcoded user ID

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('address')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final streetOne = data['streetone'] ?? '';
      final streetTwo = data['streettwo'] ?? '';
      final city = data['city'] ?? '';
      final state = data['state'] ?? '';
      final zipcode = data['zipcode'] ?? '';

      // Combine all address fields into a formatted string
      return '$streetOne, $streetTwo, $city, $state, $zipcode';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select Shipping Address',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _fetchFormattedAddresses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No addresses found.'));
                }

                final addresses = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    return _buildAddressOption(address, () {
                      onAddressSelected(address);
                      Navigator.pop(context);
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressOption(String address, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF8B5CF6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(address),
        trailing: const Icon(Icons.check_circle, color: Color(0xFF8B5CF6)),
        onTap: onTap,
      ),
    );
  }
}
