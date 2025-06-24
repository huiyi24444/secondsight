import 'package:flutter/material.dart';
import 'package:algolia/algolia.dart';
import 'package:secondsight/model/product_model.dart';
import 'package:secondsight/view/widgets/product_card.dart';
import 'package:secondsight/services/algolia_service.dart';
import 'package:secondsight/view/widgets/searchBar.dart';
import 'package:secondsight/view/widgets/price_range_selector.dart';

import 'package:cloud_functions/cloud_functions.dart';

class SearchResultsView extends StatefulWidget {
  final String keyword;

  const SearchResultsView({super.key, required this.keyword});

  @override
  State<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<SearchResultsView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Product> _results = [];
  bool _isLoading = true;

  double? minPrice;
  double? maxPrice;
  String sortOption = 'recommended';

  List<String> selectedSizes = [];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.keyword;
    _performSearch();
    //triggerReindexing();



  }

  //void triggerReindexing() async {
  //     try {
  //       final result = await FirebaseFunctions.instance
  //           .httpsCallable('triggerReindexing')
  //           .call();
  //
  //       print(result.data); // Should say: {message: 'Reindexed X products'}
  //     } catch (e) {
  //       print('Reindex error: $e');
  //     }
  //   }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);

    AlgoliaQuery query = AlgoliaService.algolia
        .index('products')
        .query(widget.keyword);

    List<String> filters = [];

    if (minPrice != null) filters.add('productPrice >= $minPrice');
    if (maxPrice != null) filters.add('productPrice <= $maxPrice');
    if (selectedSizes.isNotEmpty) {
      final sizeFilter = selectedSizes
          .map((size) => 'productSize:"$size"') // assumes productSize is flattened
          .join(' OR ');
      filters.add('($sizeFilter)');
    }

    if (filters.isNotEmpty) {
      query = query.setFilters(filters.join(' AND '));
    }

    // Sorting via replica index
    switch (sortOption) {
      case 'newest':
        query = AlgoliaService.algolia
            .index('products_newest')
            .query(widget.keyword);
        break;
      case 'low_to_high':
        query = AlgoliaService.algolia
            .index('products_price_asc')
            .query(widget.keyword);
        break;
      case 'high_to_low':
        query = AlgoliaService.algolia
            .index('products_price_desc')
            .query(widget.keyword);
        break;
    }

    final AlgoliaQuerySnapshot snap = await query.getObjects();
    final results = snap.hits
        .map((hit) => Product.fromAlgolia(hit.data, hit.objectID)) // ✅ pass ID here
        .toList();

    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  void _openSizeSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (_) {
        final sizes = ['S', 'M', 'L', 'XL'];
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(25, 20, 25, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select Sizes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    children: sizes.map((size) {
                      final isSelected = selectedSizes.contains(size);
                      return FilterChip(
                        label: Text(size),
                        selected: isSelected,
                        onSelected: (_) {
                          setModalState(() {
                            if (isSelected) {
                              selectedSizes.remove(size);
                            } else {
                              selectedSizes.add(size);
                            }
                          });
                        },
                        selectedColor: Colors.deepPurple.shade200,
                        backgroundColor: const Color(0xFFF4F4F4),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {}); // Update main UI too
                      _performSearch();
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.fromLTRB(25, 5, 25, 50),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Spacer(),
                  const Text(
                    'Sort by',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              _buildSortOption('Recommended', 'recommended'),
              _buildSortOption('Newest', 'newest'),
              _buildSortOption('Lowest - Highest Price', 'low_to_high'),
              _buildSortOption('Highest - Lowest Price', 'high_to_low'),
            ],
          ),
        );
      },
    );
  }

  void _openPriceSheet() {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.fromLTRB(25, 18, 25, 50),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filter by Price',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              PriceRangeSelector(
                min: 1,
                max: 500,
                onChanged: (min, max) {
                  setState(() {
                    minPrice = min;
                    maxPrice = max;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performSearch();
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, String value) {
    final isSelected = sortOption == value;

    return GestureDetector(
      onTap: () {
        setState(() => sortOption = value);
        Navigator.pop(context);
        _performSearch();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        // spacing between items
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.deepPurple.shade100 : const Color(0xFFF4F4F4),

          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            if (isSelected) const Icon(Icons.check, color: Colors.deepPurple),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceInputBox({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: Color(0xFF737373)),
          filled: true,
          fillColor: Color(0xFFF4F4F4),
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomSearchBar(
                  controller: _searchController,
                  focusNode: _focusNode,
                  readOnly: false,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: Wrap(
              spacing: 8,
              children: [

                _buildChip(label: 'Price', onTap: _openPriceSheet),
                _buildChip(label: 'Sort by', onTap: _openSortSheet),
                _buildChip(
                  label: selectedSizes.isNotEmpty
                      ? 'Size: ${selectedSizes.join(", ")}'
                      : 'Size',
                  onTap: _openSizeSheet,
                ),

                // Add more filter chips like price range here
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                    ? Align(
                      alignment: Alignment.topCenter,

                      child: Column(
                        children: [
                          SizedBox(height: 50),
                          Image.asset(
                            'assets/images/no_results.png',
                            width: 280,
                            height: 280,
                            fit: BoxFit.contain,
                          ),
                          const Text(
                            "Sorry, we couldn't find any ",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                            ),
                          ),
                          const Text(
                            "matching result for your Search.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    )
                    : GridView.count(
                      crossAxisCount: 2,
                  childAspectRatio: 0.65,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                      crossAxisSpacing: 0,
                      children:
                          _results.map((p) => ProductCard(product: p)).toList(),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(label),
        backgroundColor: Colors.deepPurple.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}
