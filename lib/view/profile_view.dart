import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/profile_model.dart';
import 'address_list_view.dart';
import 'payment_method_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late Future<ProfileModel> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadUserProfile();
  }

  Future<ProfileModel> _loadUserProfile() async {
    final userId = "sBblLZO4yToH2lCJjw4N"; // Replace with FirebaseAuth.instance.currentUser!.uid
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (!doc.exists) {
      throw Exception("User not found");
    }

    return ProfileModel.fromJson(doc.data()!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<ProfileModel>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: \${snapshot.error}"));
          }

          final profile = snapshot.data!;

          return Column(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(profile.profilePic),
              ),
              const SizedBox(height: 10),
              Text(
                profile.fullName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                profile.email,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              _buildMenuList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenuList() {
    final userId = "sBblLZO4yToH2lCJjw4N";
    return Expanded(
      child: ListView(
        children: [
          _buildListTile(Icons.location_on, "Address", () {
            Navigator.push(
              context,
                MaterialPageRoute(
                  builder: (_) => AddressListView(userId: userId),
                )
            );
          }),
          _buildListTile(Icons.favorite, "Wishlist", () {}),
          _buildListTile(Icons.payment, "Payment", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentMethodView(cards: [], paypalEmail: 'Cloth@gmail.com')),
            );
          }),
          _buildListTile(Icons.help_outline, "Help", () {}),
          _buildListTile(Icons.support_agent, "Support", () {}),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () {},
              child: const Text("Sign Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}