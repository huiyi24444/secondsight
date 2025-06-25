import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:secondsight/model/category_model.dart';
import 'package:secondsight/view/products/product_view.dart';
import 'package:secondsight/view/search/search_view.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secondsight/view/widgets/searchBar.dart';
import 'package:secondsight/view/settings/profile_view.dart';

import '../checkout/cart_view.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _current = 0;
  late Future<DocumentSnapshot> _profileFuture;
  final List<String> imageList = [
//TODO: ADD IAMGES
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

    // Delay access to context by scheduling it after initState completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = Provider.of<AuthProvider>(context, listen: false).userId;
      setState(() {
        _profileFuture = FirebaseFirestore.instance.collection('users').doc(userId).get();
      });
    });

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


  // search function
  Stream<QuerySnapshot> _getSearchResults() {
    if (_searchText.isEmpty) {
      return FirebaseFirestore.instance.collection('products').limit(10).snapshots(); // or return empty Stream
    }

    return FirebaseFirestore.instance
        .collection('products')
        .orderBy('productName')
        .startAt([_searchText])
        .endAt(['$_searchText\uf8ff'])
        .snapshots();
  }



  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context).userId;

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
                      child: Icon(Icons.error),
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
                onPressed: () {},
                icon: const Icon(Icons.messenger_outline),
                color: Colors.black,
                iconSize: 27,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  color: Colors.white,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CartView(userId: userId),
                      ),
                    );
                  },


                ),
              ),
            ),
          ],
        ),
      ),
    body: SafeArea(
    child: SingleChildScrollView(
    padding: const EdgeInsets.only(top: 0.0, left: 20.0, right: 20.0, bottom: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Bar
            CustomSearchBar(
              controller: TextEditingController(),
              readOnly: true,
              onSearchSubmitted: (keyword) {
                print("Searched: $keyword"); // You can use this to filter/search
              },
            ),


            const SizedBox(height: 20),

            // Carousel Slider
            CarouselSlider(
              items: imageList
                  .map((item) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
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
                  }),
            ),

            const SizedBox(height: 10),

            // Dot Indicators
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
            //categories title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Categories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // categories row
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
                    children: [
                      const SizedBox(width: 20),
                      ...categories.map((category) {
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
                                      builder: (_) => ProductView(categoryRef: categoryRef),
                                    ),
                                  );;
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
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // recommended title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recommended',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to all categories page
                  },
                  child: Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New In',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to all categories page
                  },
                  child: Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}
