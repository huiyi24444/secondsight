import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:secondsight/model/category_model.dart';
import 'package:secondsight/view/products/product_view.dart';
import 'package:secondsight/view/search/search_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/view/products/new_section.dart';
import 'package:secondsight/view/widgets/searchBar.dart';
import 'package:secondsight/view/settings/profile_view.dart';
import '../../model/product_model.dart';
import '../../services/lazy_loading_grid.dart';
import '../../services/recommendation_service.dart';
import '../chat/chat_order_selection.dart';
import '../checkout/cart_view.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../order/notifications_view.dart';
import '../order/order_tracking_view.dart';
import '../order/orders_view.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/cart_icon_widget.dart';
import '../widgets/product_card.dart';
import 'carousel.dart';
import 'rec_section.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _current = 0;

  late Future<DocumentSnapshot> _profileFuture;
  String? _currentUserId;

  final List<String> imageList = [
    'assets/images/banner1.jpg',
    'assets/images/banner2.jpg',
    'assets/images/banner3.jpg',
  ];

  final CarouselController _controller = CarouselController();
  late Future<List<Category>> _categoriesFuture;

  // Add a key for the RecommendationsSection to force rebuild
  Key _recommendationsKey = UniqueKey();
  Key _newProductsKey = UniqueKey();

  Future<List<Category>> fetchCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('category')
        .get();
    return snapshot.docs.map((doc) => Category.fromDocument(doc)).toList();
  }

  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _categoriesFuture = fetchCategories();

    final userId = Provider.of<AuthProvider>(context, listen: false).userId;
    if (userId != null) {
      OfflineRecommendationService().generateRecommendations(
        showProgress: true,
      );
      debugPrint(
        '[OfflineRecommendationService] generateRecommendations() triggered',
      );
    }

    _searchController.addListener(() {
      final newText = _searchController.text.trim();
      // Only update state if the text actually changed
      if (newText != _searchText) {
        setState(() {
          _searchText = newText;

          if (newText.isNotEmpty && !_recentSearches.contains(newText)) {
            _recentSearches.insert(0, newText);
            if (_recentSearches.length > 10) {
              _recentSearches = _recentSearches.sublist(0, 10);
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showLoginPrompt(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text('Login Required'),
          content: Text('Please login to access $feature'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E6CEF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/login');
              },
              child: const Text('Login'),
            ),
          ],
        );
      },
    );
  }

  // Add refresh method
  Future<void> _refreshData() async {
    // Show loading indicator for at least 1 second for better UX
    await Future.delayed(const Duration(seconds: 1));

    final userId = Provider.of<AuthProvider>(context, listen: false).userId;
    if (userId != null) {
      await OfflineRecommendationService().generateRecommendations(
        showProgress: true,
      );
    }

    setState(() {
      // Refresh categories
      _categoriesFuture = fetchCategories();

      // Force rebuild of recommendation and new products sections by changing keys
      _recommendationsKey = UniqueKey();
      _newProductsKey = UniqueKey();

      // Refresh profile if userId exists
      if (_currentUserId != null) {
        _profileFuture = FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .get();
      }
    });
  }

  // Updated MyHomePage build method - Replace your current build method with this
  @override
  Widget build(BuildContext context) {
    print('MyHomePage building at ${DateTime.now()}');

    // Get auth status
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.userId;
    final bool isLoggedIn = authProvider.isLoggedIn;


    // Only create profile future if user is logged in
    if (isLoggedIn && _currentUserId != userId && userId != null) {
      _currentUserId = userId;
      _profileFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 10.0),
            child: GestureDetector(
              onTap: () {
                if (isLoggedIn) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileView(),
                    ),
                  );
                } else {
                  _showLoginPrompt(context, 'profile');
                }
              },
              child: isLoggedIn
                  ? FutureBuilder<DocumentSnapshot>(
                      future: _profileFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        if (snapshot.hasError ||
                            !snapshot.hasData ||
                            !snapshot.data!.exists) {
                          return const CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, size: 20),
                          );
                        }
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        final imageUrl = data['profilePic'] ?? '';
                        return CircleAvatar(
                          radius: 20,
                          backgroundImage: imageUrl.isNotEmpty
                              ? NetworkImage(imageUrl)
                              : NetworkImage(
                                  'https://firebasestorage.googleapis.com/v0/b/secondsight-5cba4.firebasestorage.app/o/temp_profile_icon.jpg?alt=media&token=6ba2703e-e802-4738-bcb5-eaa796488294',
                                ),
                          backgroundColor: Colors.grey,
                        );
                      },
                    )
                  : const CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFF8E6CEF),
                      child: Icon(
                        Icons.person_outline,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              height: 61,
              child: Image.asset(
                'assets/images/secondsight_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          centerTitle: true,
          actions: [
            if (isLoggedIn)
              Padding(
                padding: const EdgeInsets.only(right: 1.0, top: 12),
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatSupportView(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.messenger_outline),
                  color: Colors.black,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 12),
              child: isLoggedIn
                  ? CartIconWithBadge()
                  : IconButton(
                      onPressed: () {
                        _showLoginPrompt(context, 'shopping cart');
                      },
                      icon: const Icon(Icons.shopping_cart_outlined),
                      color: Colors.black,
                    ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: Theme.of(context).primaryColor,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomSearchBar(
                  controller: TextEditingController(),
                  readOnly: true,
                  onSearchSubmitted: (keyword) {
                    print("Searched: $keyword");
                  },
                ),
                const SizedBox(height: 20),
                if (imageList.isNotEmpty) ...[
                  HomeCarousel(imageList: imageList),
                  const SizedBox(height: 20),
                ],
                const Text(
                  'Categories',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<Category>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Text('Failed to load categories');
                    }
                    final categories = snapshot.data!;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((category) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Column(
                              children: [
                                IconButton(
                                  icon: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: category.catURL,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[200],
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.category),
                                          ),
                                    ),
                                  ),
                                  iconSize: 60,
                                  onPressed: () {
                                    final categoryRef = FirebaseFirestore
                                        .instance
                                        .collection('category')
                                        .doc(category.id);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProductView(
                                          categoryRef: categoryRef,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  category.catName,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Recommendations section - show for ALL users
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isLoggedIn ? 'Recommended For You' : 'Recommended For You',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductView(
                              userId: userId, // Pass userId (can be null)
                              isRecommendations: true,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'View More',
                        style: TextStyle(
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          color: Color(0xFF8E6CEF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),

                // Always show recommendations section
                RecommendationsSection(
                  userId: userId, // Can be null for non-logged-in users
                  showDebugInfo:
                      isLoggedIn, // Only show debug info for logged-in users
                ),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'New In',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProductView(isNewIn: true),
                          ),
                        );
                      },
                      child: const Text(
                        'View More',
                        style: TextStyle(
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          color: Color(0xFF8E6CEF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                NewProductsHorizontalSection(),
                const SizedBox(height: 20),

                // Login prompt for non-authenticated users
                if (!isLoggedIn)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E6CEF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Join SecondSight',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign up to get personalized recommendations, save favorites, and more!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/login');
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF8E6CEF),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Login'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/register');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8E6CEF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Sign Up'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: 0,
        onItemTapped: (index) {
          if (index == 0) return;

          Widget? target;
          switch (index) {
            case 1:
              if (isLoggedIn) {
                target = const NotificationsView();
              } else {
                _showLoginPrompt(context, 'notifications');
                return;
              }
              break;
            case 2:
              if (isLoggedIn) {
                target = const OrdersView();
              } else {
                _showLoginPrompt(context, 'orders');
                return;
              }
              break;
            case 3:
              if (isLoggedIn) {
                target = const ProfileView();
              } else {
                Navigator.pushNamed(context, '/login');
                return;
              }
              break;
            default:
              return;
          }

          if (target != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => target!),
            );
          }
        },
      ),
    );
  }
}
