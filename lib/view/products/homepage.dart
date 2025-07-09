  import 'package:flutter/material.dart';
  import 'package:carousel_slider/carousel_slider.dart';
  import 'package:secondsight/model/category_model.dart';
  import 'package:secondsight/view/products/product_view.dart';
  import 'package:secondsight/view/search/search_view.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:secondsight/view/widgets/searchBar.dart';
  import 'package:secondsight/view/settings/profile_view.dart';
  import '../../model/product_model.dart';
  import '../../services/lazy_loading_grid.dart';
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

  class MyHomePage extends StatefulWidget {
    const MyHomePage({super.key});

    @override
    State<MyHomePage> createState() => _MyHomePageState();
  }

  class _MyHomePageState extends State<MyHomePage> {
    int _current = 0;
    late Future<DocumentSnapshot> _profileFuture;


    final List<String> imageList = [
      'assets/images/banner1.jpg',
      'assets/images/banner2.jpg',
      'assets/images/banner3.jpg',
    ];

    final CarouselSliderController _controller = CarouselSliderController();
    late Future<List<Category>> _categoriesFuture;

    Future<List<Category>> fetchCategories() async {
      final snapshot = await FirebaseFirestore.instance.collection('category').get();
      return snapshot.docs.map((doc) => Category.fromDocument(doc)).toList();
    }

    final TextEditingController _searchController = TextEditingController();
    String _searchText = '';
    List<String> _recentSearches = [];

    @override
    void initState() {
      super.initState();
      _categoriesFuture = fetchCategories();

      _searchController.addListener(() {
        final text = _searchController.text.trim();
        setState(() {
          _searchText = text;
          if (text.isNotEmpty && !_recentSearches.contains(text)) {
            _recentSearches.insert(0, text);
            if (_recentSearches.length > 10) {
              _recentSearches = _recentSearches.sublist(0, 10);
            }
          }
        });
      });
    }

    @override
    void didChangeDependencies() {
      super.didChangeDependencies();
      final userId = Provider.of<AuthProvider>(context).userId;

      if (userId != null) {
        _profileFuture = FirebaseFirestore.instance.collection('users').doc(userId).get();
      }
    }



    @override
    void dispose() {
      _searchController.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      final userId = Provider.of<AuthProvider>(context).userId;
      if (userId == null) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileView()),
                  );
                },
                child: FutureBuilder<DocumentSnapshot>(
                  future: _profileFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                      return const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, size: 20),
                      );
                    }
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final imageUrl = data['profilePic'] ?? '';
                    return CircleAvatar(
                      radius: 20,
                      backgroundImage: imageUrl.isNotEmpty
                          ? NetworkImage(imageUrl)
                          : const AssetImage('assets/images/default_avatar.png')
                      as ImageProvider,
                      backgroundColor: Colors.grey,
                    );
                  },
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
              Padding(
                padding: const EdgeInsets.only(top: 15.0, right: 8.0, left: 4.0),
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatSupportView()),
                    );
                  },
                  icon: const Icon(Icons.messenger_outline),
                  color: Colors.black,
                  iconSize: 27,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0, top: 12),
                child: CartIconWithBadge(),  // Removed 'const'
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                CustomSearchBar(
                  controller: TextEditingController(),
                  readOnly: true,
                  onSearchSubmitted: (keyword) {
                    print("Searched: $keyword");
                  },
                ),
                const SizedBox(height: 20),

                // Carousel
                if (imageList.isNotEmpty) ...[
                  CarouselSlider(
                    items: imageList
                        .map((item) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        item,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ))
                        .toList(),
                    carouselController: _controller,
                    options: CarouselOptions(
                      height: 180,
                      autoPlay: true,
                      enlargeCenterPage: true,
                      viewportFraction: 0.9,
                      onPageChanged: (index, reason) {
                        setState(() {
                          _current = index;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: imageList.asMap().entries.map((entry) {
                      return GestureDetector(
                        onTap: () => _controller.animateToPage(entry.key),
                        child: Container(
                          width: 10.0,
                          height: 10.0,
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _current == entry.key
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // Categories
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
                                    child: Image.network(
                                      category.catURL,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
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
                                    final categoryRef = FirebaseFirestore.instance
                                        .collection('category')
                                        .doc(category.id);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ProductView(categoryRef: categoryRef),
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
                const Text(
                  'Recommended',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'New In',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerRight,
                      ),
                      child: const Text(
                        'View More',
                        style: TextStyle(
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Product Grid
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('products')
                      .orderBy('createdAt', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;
                    final products = docs
                        .map((doc) => Product.fromDocumentSnapshot(doc))
                        .toList();

                    return SizedBox(
                      height: 270,
                      child: ListView.builder(
                        itemCount: products.length,
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(), // Prevents overscroll
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: SizedBox(
                              width: 160,
                              child: ProductCard(product: products[index]),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        bottomNavigationBar: BottomNavBar(
          selectedIndex: 0,
          onItemTapped: (index) {
            if (index == 0) return;
            Widget target;
            switch (index) {
              case 1:
                target = const NotificationsView();
                break;
              case 2:
                target = const OrdersView();
                break;
              case 3:
                target = const ProfileView();
                break;
              default:
                return;
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => target),
            );
          },
        ),
      );
    }
  }