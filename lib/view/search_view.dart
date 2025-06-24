import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secondsight/view/widgets/searchBar.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
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
      _recentSearches.remove(keyword); // Remove if already exists
      _recentSearches.insert(0, keyword); // Add to front
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
    Navigator.pop(context, keyword);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomSearchBar(
              controller: _searchController,
              focusNode: _focusNode,
              readOnly: false,
              onSearchSubmitted: _submitSearch, // 🔥 connects enter key to saving
            ),
            const SizedBox(height: 20),
            const Text(
              'Recent Searches',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _recentSearches.isEmpty
                  ? const Center(child: Text('No recent searches'))
                  : SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recentSearches.map((term) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchController.text = term;
                          _focusNode.requestFocus(); // Optional: refocus to allow editing
                        });
                      },
                      child: Chip(
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
                        deleteIcon: const Icon(Icons.close, color: Colors.white),
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
        ),
      ),
    );
  }
}
