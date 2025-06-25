import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/view/products/wishlist_view.dart';
import '../../model/profile_model.dart';
import '../widgets/custom_back_button.dart';
import 'address_list_view.dart';
import 'payment_method_view.dart';
import 'edit_profile_view.dart'; // Add this import

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

  void _refreshProfile() {
    setState(() {
      _profileFuture = _loadUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text(
          "Settings",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<ProfileModel>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          final profile = snapshot.data!;

          return Column(
            children: [
              // Profile Header Section
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF8E6CEF).withOpacity(0.2),
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Image.network(
                              profile.profilePic,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Edit Profile Button
                    TextButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileView(
                              userId: "sBblLZO4yToH2lCJjw4N",
                              profile: profile,
                            ),
                          ),
                        );

                        // Refresh profile if edited
                        if (result == true) {
                          _refreshProfile();
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8E6CEF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: const Color(0xFF8E6CEF).withOpacity(0.3),
                          ),
                        ),
                      ),
                      child: const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Menu List
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: _buildMenuList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenuList() {
    final userId = "sBblLZO4yToH2lCJjw4N";
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildListTile(
          Icons.location_on_outlined,
          "Address",
              () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddressListView(userId: userId),
              ),
            );
          },
        ),
        _buildListTile(
          Icons.favorite_outline,
          "Wishlist",
              () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WishlistView(userId: userId),
              ),
            );
          },
        ),
        _buildListTile(
          Icons.payment_outlined,
          "Payment",
              () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PaymentMethodView(
                  cards: [],
                  paypalEmail: 'Cloth@gmail.com',
                ),
              ),
            );
          },
        ),
        _buildListTile(
          Icons.help_outline,
          "Help",
              () {},
        ),
        _buildListTile(
          Icons.support_agent_outlined,
          "Support",
              () {},
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextButton(
            onPressed: () {
              // Add sign out logic here
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Sign Out",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildListTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF8E6CEF).withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF8E6CEF),
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey[400],
        size: 22,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}