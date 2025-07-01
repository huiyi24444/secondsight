import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShippingAddressSelection extends StatefulWidget {
  final Function(String) onAddressSelected;

  const ShippingAddressSelection({required this.onAddressSelected, Key? key}) : super(key: key);

  @override
  State<ShippingAddressSelection> createState() => _ShippingAddressSelectionState();
}

class _ShippingAddressSelectionState extends State<ShippingAddressSelection> {
  int? selectedIndex;

  Future<List<String>> _fetchFormattedAddresses() async {
    const userId = 'sBblLZO4yToH2lCJjw4N';

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
                    return _buildAddressOption(address, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressOption(String address, int index) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedIndex = index;
        });

        // Call the callback and close the bottom sheet
        widget.onAddressSelected(address);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          title: Text(address),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: Color(0xFF8B5CF6))
              : null,
        ),
      ),
    );
  }
}

