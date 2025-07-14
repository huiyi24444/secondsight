import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../settings/add_address_view.dart';
import '../../model/address_model.dart'; // Import your AddressModel

class ShippingAddressSelection extends StatefulWidget {
  final Function(AddressModel) onAddressSelected; // Changed to pass AddressModel
  final String userId;
  final AddressModel? initiallySelectedAddress;

  const ShippingAddressSelection({
    required this.userId,
    required this.onAddressSelected,
    this.initiallySelectedAddress,
    Key? key,
  }) : super(key: key);

  @override
  State<ShippingAddressSelection> createState() => _ShippingAddressSelectionState();
}

class _ShippingAddressSelectionState extends State<ShippingAddressSelection> {
  int? selectedIndex;

  Future<List<AddressModel>> _fetchAddresses() async {
    final userId = widget.userId;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('address')
        .orderBy('isDefault', descending: true)
        .get();

    final addresses = snapshot.docs.map((doc) {
      final data = doc.data();
      return AddressModel(
        fullName: data['fullName'] ?? '',
        phoneNum: data['phoneNum'] ?? 0,
        isDefault: data['isDefault'] ?? false,
        street: '${data['streetone'] ?? ''} ${data['streettwo'] ?? ''}'.trim(),
        city: data['city'] ?? '',
        state: data['state'] ?? '',
        zipCode: data['zipCode']?.toString() ?? data['zipcode']?.toString() ?? '',
      );
    }).toList();

// 🔥 Determine selectedIndex based on match or fallback
    if (selectedIndex == null) {
      if (widget.initiallySelectedAddress != null) {
        final existingIndex = addresses.indexWhere((addr) =>
        addr.fullName == widget.initiallySelectedAddress!.fullName &&
            addr.street == widget.initiallySelectedAddress!.street &&
            addr.city == widget.initiallySelectedAddress!.city &&
            addr.zipCode == widget.initiallySelectedAddress!.zipCode
        );

        if (existingIndex != -1) {
          selectedIndex = existingIndex;
        }
      }

      // fallback to default
      if (selectedIndex == null) {
        final defaultIndex = addresses.indexWhere((addr) => addr.isDefault);
        if (defaultIndex != -1) selectedIndex = defaultIndex;
      }
    }


    // Automatically set selectedIndex to the default address (first one with isDefault == true)
    final defaultIndex = addresses.indexWhere((addr) => addr.isDefault);
    if (defaultIndex != -1 && selectedIndex == null) {
      // Only auto-select once
      selectedIndex = defaultIndex;
      // Call callback with default address
    }

    return addresses;
  }


  String _formatAddress(AddressModel address) {
    // Format address for display
    final parts = <String>[];

    if (address.street.isNotEmpty) parts.add(address.street);
    if (address.city.isNotEmpty) parts.add(address.city);
    if (address.state.isNotEmpty) parts.add(address.state);
    if (address.zipCode.isNotEmpty) parts.add(address.zipCode);

    return parts.join(', ');
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
            child: FutureBuilder<List<AddressModel>>(
              future: _fetchAddresses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No addresses found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first shipping address',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddAddressView(userId: widget.userId),
                  ),
                );

                if (mounted) {
                  setState(() {
                    // Refresh the address list
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E6CEF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Add Address',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: 10)
        ],
      ),
    );
  }

  Widget _buildAddressOption(AddressModel address, int index) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (selectedIndex == index) {
          // Deselect the address
          setState(() {
            selectedIndex = null;
          });
        } else {
          // Select new address and close sheet
          setState(() {
            selectedIndex = index;
          });
          widget.onAddressSelected(address);
        }
      },



      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF8E6CEF) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF8E6CEF).withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          address.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8E6CEF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Phone: ${address.phoneNum}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatAddress(address),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF8E6CEF),
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}