import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secondsight/view/widgets/searchBar.dart';
import 'package:algolia/algolia.dart';
import 'package:secondsight/services/algolia_service.dart';
import 'package:secondsight/model/product_model.dart';
import 'package:secondsight/view/search/search_results_view.dart';
import 'dart:async';

import '../widgets/custom_back_button.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
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
    _loadRecentSearches();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
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
        _generateDynamicSuggestions(query);
      });
    } else {
      // For single character, use fallback terms for instant feedback
      setState(() {
        _showSuggestions = true;
        _isSearching = false;
      });
      _generateFallbackSuggestions(query);
    }
  }

  Future<void> _generateDynamicSuggestions(String query) async {
    if (!mounted) return;

    print('Generating dynamic suggestions for: "$query"');

    try {
      // Check if AlgoliaService is available
      if (AlgoliaService.algolia == null) {
        print('AlgoliaService not available, using fallback');
        _generateFallbackSuggestions(query);
        return;
      }

      Set<String> suggestions = {};

      // Method 1: Search for terms in product names and extract keywords
      await _extractTermsFromProductNames(query, suggestions);

      // Method 2: Use Algolia facets if configured
      await _extractTermsFromFacets(query, suggestions);

      // Method 3: Extract from product categories
      await _extractTermsFromCategories(query, suggestions);

      // Convert to list and sort by relevance
      List<String> sortedSuggestions = suggestions.toList();
      _sortSuggestionsByRelevance(sortedSuggestions, query);

      if (mounted) {
        setState(() {
          _searchSuggestions = sortedSuggestions.take(8).toList();
          _isSearching = false;
        });
      }

      print('Generated ${_searchSuggestions.length} dynamic suggestions');

    } catch (e) {
      print('Error generating dynamic suggestions: $e');
      // Fallback to predefined terms
      _generateFallbackSuggestions(query);
    }
  }

  Future<void> _extractTermsFromProductNames(String query, Set<String> suggestions) async {
    try {
      // Search for products that match the query
      final AlgoliaQuery algoliaQuery = AlgoliaService.algolia
          .index('products')
          .query(query)
          .setHitsPerPage(50); // Get more products to extract terms from

      final AlgoliaQuerySnapshot snap = await algoliaQuery.getObjects();

      for (var hit in snap.hits) {
        final productName = hit.data['productName'] as String? ?? '';

        // Extract relevant terms from product names
        final words = productName.toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), ' ') // Remove special characters
            .split(' ')
            .where((word) => word.length > 2) // Filter short words
            .toList();

        for (String word in words) {
          // Add words that contain our query
          if (word.contains(query) && word.length >= query.length) {
            suggestions.add(word);
          }

          // Add common clothing terms found in product names
          if (_isClothingTerm(word)) {
            suggestions.add(word);
          }
        }

        // Add category-like terms from product descriptions
        final description = hit.data['productDesc'] as String? ?? '';
        _extractClothingTermsFromText(description.toLowerCase(), suggestions, query);
      }

    } catch (e) {
      print('Error extracting terms from product names: $e');
    }
  }

  Future<void> _extractTermsFromFacets(String query, Set<String> suggestions) async {
    try {
      // For the Algolia Flutter package, we'll extract terms differently
      // Since direct facet access isn't available, we'll search for broader terms
      // and extract unique values from specific fields

      final categoryTerms = ['shirt', 'dress', 'jean', 'pant', 'shoe', 'bag', 'jacket'];

      for (String term in categoryTerms) {
        if (term.contains(query)) {
          final AlgoliaQuery algoliaQuery = AlgoliaService.algolia
              .index('products')
              .query(term)
              .setHitsPerPage(20);

          final AlgoliaQuerySnapshot snap = await algoliaQuery.getObjects();

          // Extract unique terms from product data
          for (var hit in snap.hits) {
            // Extract from product condition field
            final condition = hit.data['productCondition'] as String? ?? '';
            if (condition.isNotEmpty && condition.toLowerCase().contains(query)) {
              suggestions.add(condition.toLowerCase());
            }

            // Extract clothing type keywords from product names
            final productName = hit.data['productName'] as String? ?? '';
            final nameWords = productName.toLowerCase().split(' ');
            for (String word in nameWords) {
              if (word.length > 3 && word.contains(query) && _isClothingTerm(word)) {
                suggestions.add(word);
              }
            }
          }
        }
      }

    } catch (e) {
      print('Error extracting terms from facets: $e');
      // This is expected if there are API issues
    }
  }

  Future<void> _extractTermsFromCategories(String query, Set<String> suggestions) async {
    try {
      // Search through different product fields to find category-like terms
      final AlgoliaQuery algoliaQuery = AlgoliaService.algolia
          .index('products')
          .query(query)
          .setHitsPerPage(30);

      final AlgoliaQuerySnapshot snap = await algoliaQuery.getObjects();

      Set<String> uniqueTerms = {};

      for (var hit in snap.hits) {
        // Extract from product condition
        final condition = hit.data['productCondition'] as String? ?? '';
        if (condition.isNotEmpty) {
          uniqueTerms.add(condition.toLowerCase());
        }

        // Extract from product status if it contains clothing terms
        final status = hit.data['productStatus'] as String? ?? '';
        if (status.isNotEmpty && _containsClothingKeywords(status)) {
          uniqueTerms.add(status.toLowerCase());
        }

        // Try to extract category info from product description
        final description = hit.data['productDesc'] as String? ?? '';
        _extractClothingTermsFromText(description.toLowerCase(), uniqueTerms, query);
      }

      // Add terms that match our query
      for (String term in uniqueTerms) {
        if (term.contains(query) && term.length >= query.length) {
          suggestions.add(term);
        }
      }

    } catch (e) {
      print('Error extracting terms from categories: $e');
    }
  }

  bool _containsClothingKeywords(String text) {
    final clothingKeywords = ['shirt', 'dress', 'jean', 'pant', 'shoe', 'bag', 'jacket', 'top'];
    return clothingKeywords.any((keyword) => text.toLowerCase().contains(keyword));
  }

  void _extractClothingTermsFromText(String text, Set<String> suggestions, String query) {
    // Common clothing-related keywords to look for
    final clothingKeywords = [
      'shirt', 'blouse', 'top', 'dress', 'jean', 'pant', 'trouser',
      'skirt', 'short', 'jacket', 'coat', 'sweater', 'hoodie',
      'shoe', 'sneaker', 'boot', 'heel', 'flat', 'sandal',
      'bag', 'handbag', 'backpack', 'tote',
      'casual', 'formal', 'party', 'office', 'summer', 'winter',
      'cotton', 'denim', 'silk', 'wool', 'leather',
      'vintage', 'retro', 'modern', 'classic'
    ];

    // Split text into words
    final words = text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(' ')
        .where((word) => word.length > 2)
        .toList();

    for (String word in words) {
      // Add if it's a clothing keyword and contains our query
      if (clothingKeywords.contains(word) && word.contains(query)) {
        suggestions.add(word);
      }

      // Add if it's a word that contains our query and seems clothing-related
      if (word.contains(query) && _isLikelyClothingTerm(word)) {
        suggestions.add(word);
      }
    }
  }

  bool _isLikelyClothingTerm(String word) {
    // Check if word contains common clothing suffixes or prefixes
    final clothingIndicators = [
      'wear', 'shirt', 'dress', 'pant', 'jean', 'coat', 'jacket',
      'shoe', 'boot', 'bag', 'top', 'size', 'fit'
    ];

    return clothingIndicators.any((indicator) =>
    word.contains(indicator) || indicator.contains(word));
  }

  bool _isClothingTerm(String word) {
    final clothingTerms = [
      'shirt', 'blouse', 'top', 'dress', 'jean', 'pant', 'skirt',
      'short', 'jacket', 'sweater', 'shoe', 'bag', 'coat', 'hoodie'
    ];

    return clothingTerms.any((term) => word.contains(term) || term.contains(word));
  }

  void _generateFallbackSuggestions(String query) {
    final suggestions = _fallbackTerms
        .where((term) => term.toLowerCase().contains(query.toLowerCase()))
        .take(8)
        .toList();

    _sortSuggestionsByRelevance(suggestions, query);

    setState(() {
      _searchSuggestions = suggestions;
      _isSearching = false;
    });
  }

  void _sortSuggestionsByRelevance(List<String> suggestions, String query) {
    suggestions.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();
      final queryLower = query.toLowerCase();

      // Exact match
      if (aLower == queryLower) return -1;
      if (bLower == queryLower) return 1;

      // Starts with query
      if (aLower.startsWith(queryLower) && !bLower.startsWith(queryLower)) return -1;
      if (bLower.startsWith(queryLower) && !aLower.startsWith(queryLower)) return 1;

      // Length (shorter terms first)
      return a.length.compareTo(b.length);
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

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsView(keyword: keyword),
      ),
    );
  }

  void _selectSuggestion(String term) {
    _searchController.text = term;
    _submitSearch(term);
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
          leading: const CustomBackButton()
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

  // Helper function to highlight search term in suggestions
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
}