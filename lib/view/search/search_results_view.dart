import 'dart:async';

import 'package:flutter/material.dart';
import 'package:algolia/algolia.dart';
import 'package:secondsight/model/product_model.dart';
import 'package:secondsight/view/widgets/product_card.dart';
import 'package:secondsight/services/algolia_service.dart';
import 'package:secondsight/view/widgets/searchBar.dart';
import 'package:secondsight/view/widgets/price_range_selector.dart';
import 'package:secondsight/view/search/search_view.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/custom_back_button.dart';

class SearchResultsView extends StatefulWidget {
  String keyword; // Remove 'final' to allow updates

  SearchResultsView({super.key, required this.keyword}); // Remove 'const'

  @override
  State<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<SearchResultsView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Product> _results = [];
  bool _isLoading = true;
  String? _errorMessage;

  bool hasVirtualTryOn = false;
  double? minPrice;
  double? maxPrice;
  String sortOption = 'recommended';

  List<String> selectedSizes = [];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.keyword;
    _performSearch();
  }

  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if AlgoliaService is properly initialized
      if (AlgoliaService.algolia == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Search service not available';
        });
        return;
      }

      // First determine which index to use based on sort option
      String indexName = 'products';
      switch (sortOption) {
        case 'newest':
          indexName = 'products_newest';
          break;
        case 'low_to_high':
          indexName = 'products_price_asc';
          break;
        case 'high_to_low':
          indexName = 'products_price_desc';
          break;
      }

      AlgoliaQuery query = AlgoliaService.algolia
          .index(indexName)
          .query(widget.keyword);

      // Build filters array
      List<String> filters = [];

      // Status filter (always applied)
      filters.add('(NOT productStatus:sold) AND (NOT productStatus:inactive)');

      // Price filters
      if (minPrice != null && minPrice! > 0) {
        filters.add('productPrice >= $minPrice');
      }
      if (maxPrice != null && maxPrice! > 0) {
        filters.add('productPrice <= $maxPrice');
      }

      if (hasVirtualTryOn) {
        filters.add('virtualTryOn.enabled:true');
      }

      // Size filter with proper formatting
      if (selectedSizes.isNotEmpty) {
        final sizeFilter = selectedSizes
            .map((size) => 'productSize:"$size"')
            .join(' OR ');
        filters.add('($sizeFilter)');
      }

      // Apply all filters if any exist
      if (filters.isNotEmpty) {
        final filterString = filters.join(' AND ');
        print('DEBUG: Applying filters: $filterString'); // Debug log
        query = query.setFilters(filterString);
      }

      // Set reasonable hits per page
      query = query.setHitsPerPage(50);

      final AlgoliaQuerySnapshot snap = await query.getObjects();

      print('DEBUG: Query returned ${snap.hits.length} results'); // Debug log

      final results = snap.hits
          .map((hit) => Product.fromAlgolia(hit.data, hit.objectID))
          .toList();

      setState(() {
        _results = results;
        _isLoading = false;
      });

    } catch (e) {
      print('DEBUG: Search error: $e'); // Debug log
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to search at the moment. Please try again.';
        _results.clear();
      });
    }
  }

  // Clear all filters
  void _clearAllFilters() {
    setState(() {
      minPrice = null;
      maxPrice = null;
      selectedSizes.clear();
      sortOption = 'recommended';
      hasVirtualTryOn = false; // Reset virtual try-on filter
    });
    _performSearch();
  }

  // Check if any filters are applied
  bool get hasActiveFilters {
    return minPrice != null ||
        maxPrice != null ||
        selectedSizes.isNotEmpty ||
        sortOption != 'recommended' ||
        hasVirtualTryOn; // Include virtual try-on in active filters check
  }

  // Get count of active filters
  int get activeFilterCount {
    int count = 0;
    if (minPrice != null || maxPrice != null) count++;
    if (selectedSizes.isNotEmpty) count++;
    if (sortOption != 'recommended') count++;
    if (hasVirtualTryOn) count++; // Count virtual try-on filter
    return count;
  }

  // Move _navigateToSearchView() method HERE - before build method
  void _navigateToSearchView() async {
    print('DEBUG: _navigateToSearchView called');
    // Navigate to SearchView with current search text
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchViewWithInitialText(
          initialText: _searchController.text,
        ),
      ),
    );

    // If a new search term was returned, update and search
    if (result != null && result is String && result.isNotEmpty) {
      setState(() {
        widget.keyword = result;
        _searchController.text = result;
      });
      _performSearch();
    }
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            selectedSizes.clear();
                          });
                        },
                        child: const Text('Clear'),
                      ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        minPrice = null;
                        maxPrice = null;
                      });
                      Navigator.pop(context);
                      _performSearch();
                    },
                    child: const Text('Clear'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _performSearch();
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openVirtualTryOnSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(25, 20, 25, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      const Text(
                        'Virtual Try-On',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: const Text('Show only items with Virtual Try-On'),
                      subtitle: const Text('Filter products that support AR try-on feature'),
                      value: hasVirtualTryOn,
                      onChanged: (value) {
                        setModalState(() {
                          hasVirtualTryOn = value;
                        });
                      },
                      activeColor: Colors.deepPurple,
                      secondary: const Icon(
                        Icons.camera_alt,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            hasVirtualTryOn = false;
                          });
                        },
                        child: const Text('Clear'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {}); // Update main UI
                          _performSearch();
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
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
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.shade100 : const Color(0xFFF4F4F4),
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

  Widget _buildChip({
    required String label,
    VoidCallback? onTap,
    bool isActive = false,
    VoidCallback? onDelete,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: isActive
            ? Colors.deepPurple
            : Colors.deepPurple.shade100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        deleteIcon: isActive && onDelete != null
            ? const Icon(Icons.close, size: 18, color: Colors.white)
            : null,
        onDeleted: onDelete,
      ),
    );
  }

  // Build active filters display
  Widget _buildActiveFilters() {
    List<Widget> filterChips = [];

    // Price filter
    if (minPrice != null || maxPrice != null) {
      String priceLabel = '';
      if (minPrice != null && maxPrice != null) {
        priceLabel = '\RM${minPrice!.toInt()}-\RM${maxPrice!.toInt()}';
      } else if (minPrice != null) {
        priceLabel = 'From \$${minPrice!.toInt()}';
      } else if (maxPrice != null) {
        priceLabel = 'Up to \$${maxPrice!.toInt()}';
      }

      filterChips.add(
        _buildChip(
          label: priceLabel,
          isActive: true,
          onTap: _openPriceSheet,
          onDelete: () {
            setState(() {
              minPrice = null;
              maxPrice = null;
            });
            _performSearch();
          },
        ),
      );
    }

    // Size filter
    if (selectedSizes.isNotEmpty) {
      filterChips.add(
        _buildChip(
          label: 'Size: ${selectedSizes.join(", ")}',
          isActive: true,
          onTap: _openSizeSheet,
          onDelete: () {
            setState(() {
              selectedSizes.clear();
            });
            _performSearch();
          },
        ),
      );
    }

    if (hasVirtualTryOn) {
      filterChips.add(
        _buildChip(
          label: 'Virtual Try-On',
          isActive: true,
          onTap: _openVirtualTryOnSheet,
          onDelete: () {
            setState(() {
              hasVirtualTryOn = false;
            });
            _performSearch();
          },
        ),
      );
    }

    // Sort filter
    if (sortOption != 'recommended') {
      String sortLabel = '';
      switch (sortOption) {
        case 'newest':
          sortLabel = 'Newest';
          break;
        case 'low_to_high':
          sortLabel = 'Price: Low to High';
          break;
        case 'high_to_low':
          sortLabel = 'Price: High to Low';
          break;
      }

      filterChips.add(
        _buildChip(
          label: sortLabel,
          isActive: true,
          onTap: _openSortSheet,
          onDelete: () {
            setState(() {
              sortOption = 'recommended';
            });
            _performSearch();
          },
        ),
      );
    }

    if (filterChips.isNotEmpty) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        ...filterChips.map((chip) =>
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: chip,
                            ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (activeFilterCount > 1)
                  TextButton(
                    onPressed: _clearAllFilters,
                    child: const Text(
                      'Clear All',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                child: CustomSearchBar(
                  controller: _searchController,
                  focusNode: _focusNode,
                  readOnly: true, // Make it read-only to capture taps
                  onSearchSubmitted: null, // Disable submission since it's read-only
                  onTap: _navigateToSearchView, // This now works!
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    _buildChip(
                      label: 'Price',
                      onTap: _openPriceSheet,
                      isActive: minPrice != null || maxPrice != null,
                    ),
                    _buildChip(
                      label: 'Sort by',
                      onTap: _openSortSheet,
                      isActive: sortOption != 'recommended',
                    ),
                    _buildChip(
                      label: 'Size',
                      onTap: _openSizeSheet,
                      isActive: selectedSizes.isNotEmpty,
                    ),
                    _buildChip(
                      label: 'Try-On',
                      onTap: _openVirtualTryOnSheet,
                      isActive: hasVirtualTryOn,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Active filters display
          _buildActiveFilters(),

          // Results area
          Expanded(
            child: _isLoading
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.deepPurple,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Searching...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : _errorMessage != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connection Issue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _performSearch,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
                : _results.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 120),
                  Image.asset(
                    'assets/images/no_results.png',
                    width: 250,
                    height: 250,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No results found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (hasActiveFilters)
                    Column(
                      children: [
                        Text(
                          'Try adjusting your filters',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _clearAllFilters,
                          child: const Text('Clear all filters'),
                        ),
                      ],
                    ),
                ],
              ),
            )
                : Column(
              children: [
                // Results count
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    '${_results.length} result${_results.length == 1 ? '' : 's'} found',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Products grid
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 0.60,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 1,

                    children: _results
                        .map((p) => ProductCard(product: p))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Modified SearchView to accept initial text
class SearchViewWithInitialText extends StatefulWidget {
  final String? initialText;

  const SearchViewWithInitialText({super.key, this.initialText});

  @override
  State<SearchViewWithInitialText> createState() => _SearchViewWithInitialTextState();
}

class _SearchViewWithInitialTextState extends State<SearchViewWithInitialText> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _recentSearches = [];
  List<String> _searchSuggestions = [];
  bool _isSearching = false;
  bool _showSuggestions = false;
  Timer? _debounceTimer;

  // Popular categories for fallback/initial display
  static const List<String> _popularCategories = [
    'shirts', 'dresses', 'jeans', 'shoes', 'bags', 'jackets'
  ];

  // Fallback terms when Algolia is unavailable
  static const List<String> _fallbackTerms = [
    'shirts', 'blouses', 'tops', 'dresses', 'jeans', 'pants', 'skirts',
    'shorts', 'jackets', 'sweaters', 'shoes', 'bags', 'accessories'
  ];

  @override
  void initState() {
    super.initState();

    // Set initial text if provided
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _searchController.text = widget.initialText!;
    }

    _loadRecentSearches();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        // If there's initial text, trigger suggestions
        if (widget.initialText != null && widget.initialText!.isNotEmpty) {
          _onSearchChanged();
        }
      }
    });

    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _showSuggestions = false;
        _searchSuggestions.clear();
        _isSearching = false;
      });
      return;
    }

    if (query.length >= 2) {
      setState(() {
        _showSuggestions = true;
        _isSearching = true;
      });

      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _generateFallbackSuggestions(query);
      });
    } else {
      setState(() {
        _showSuggestions = true;
        _isSearching = false;
      });
      _generateFallbackSuggestions(query);
    }
  }

  void _generateFallbackSuggestions(String query) {
    final suggestions = _fallbackTerms
        .where((term) => term.toLowerCase().contains(query.toLowerCase()))
        .take(8)
        .toList();

    setState(() {
      _searchSuggestions = suggestions;
      _isSearching = false;
    });
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recentSearches') ?? [];
    });
  }

  Future<void> _saveSearch(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    keyword = keyword.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _recentSearches.remove(keyword);
      _recentSearches.insert(0, keyword);
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.sublist(0, 10);
      }
    });

    await prefs.setStringList('recentSearches', _recentSearches);
  }

  void _submitSearch(String keyword) async {
    keyword = keyword.trim();
    if (keyword.isEmpty) return;

    await _saveSearch(keyword);

    // Return the search term to SearchResultsView
    Navigator.pop(context, keyword);
  }

  void _selectSuggestion(String term) {
    _searchController.text = term;
    _submitSearch(term);
  }

  List<TextSpan> _highlightSearchTerm(String text, String query) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return [TextSpan(text: text)];
    }

    return [
      if (index > 0) TextSpan(text: text.substring(0, index)),
      TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
      ),
      if (index + query.length < text.length)
        TextSpan(text: text.substring(index + query.length)),
    ];
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: const CustomBackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomSearchBar(
              controller: _searchController,
              focusNode: _focusNode,
              readOnly: false,
              onSearchSubmitted: _submitSearch,
            ),

            // Show dynamic suggestions when typing
            if (_showSuggestions && _searchController.text.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isSearching
                    ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Finding suggestions...'),
                    ],
                  ),
                )
                    : _searchSuggestions.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No suggestions found',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...(_searchSuggestions.map((term) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.search,
                          size: 20,
                          color: Colors.grey,
                        ),
                        title: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black),
                            children: _highlightSearchTerm(term, _searchController.text),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.north_west,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onTap: () => _selectSuggestion(term),
                      );
                    }).toList()),
                  ],
                ),
              ),
            ]

            // Show recent searches and popular categories when not typing
            else ...[
              const SizedBox(height: 20),

              // Popular categories section
              const Text(
                'Popular Categories',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _popularCategories.map((category) {
                  return GestureDetector(
                    onTap: () => _selectSuggestion(category),
                    child: Chip(
                      avatar: const Icon(Icons.trending_up, size: 16),
                      label: Text(category),
                      backgroundColor: Colors.deepPurple.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              const Text(
                'Recent Searches',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: _recentSearches.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No recent searches',
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Try searching for clothing items above',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
                    : SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _recentSearches.map((term) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchController.text = term;
                          });
                          _submitSearch(term);
                        },
                        child: Chip(
                          avatar: const Icon(Icons.history, size: 16, color: Colors.white),
                          label: Text(
                            term,
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          deleteIcon: const Icon(Icons.close, color: Colors.white, size: 16),
                          onDeleted: () {
                            setState(() {
                              _recentSearches.remove(term);
                            });
                            SharedPreferences.getInstance().then((prefs) {
                              prefs.setStringList('recentSearches', _recentSearches);
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}