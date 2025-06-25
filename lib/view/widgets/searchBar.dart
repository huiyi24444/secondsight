import 'package:flutter/material.dart';
import 'package:secondsight/view/search/search_view.dart';
import 'package:secondsight/view/search/search_results_view.dart';

class CustomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool readOnly;
  final Function(String)? onSearchSubmitted;
  final List<String> recentSearches;

  const CustomSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.readOnly = false,
    this.onSearchSubmitted,
    this.recentSearches = const [],
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (readOnly) {
          final keyword = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchView()),
          );

          if (keyword != null && keyword is String) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SearchResultsView(keyword: keyword)),
            );
          }

        }
      },
      child: AbsorbPointer(
        absorbing: readOnly,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          autofocus: !readOnly,
          decoration: InputDecoration(
            hintText: 'Search...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.grey[200],
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: onSearchSubmitted,
        ),
      ),
    );
  }
}
