// services/lazy_grid_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LazyLoadingGrid extends StatefulWidget {
  final Query query;
  final Widget Function(DocumentSnapshot doc) itemBuilder;
  final int limit;
  final String? emptyMessage;
  final int crossAxisCount;
  final double childAspectRatio;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  const LazyLoadingGrid({
    super.key,
    required this.query,
    required this.itemBuilder,
    this.emptyMessage,
    this.limit = 10,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.7,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
  });

  @override
  State<LazyLoadingGrid> createState() => _LazyLoadingGridState();
}

class _LazyLoadingGridState extends State<LazyLoadingGrid> {
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _docs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100 &&
          !_isLoading &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  Future<void> _loadMore() async {
    setState(() => _isLoading = true);

    Query query = widget.query.limit(widget.limit);
    if (_lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }

    final snapshot = await query.get();
    final newDocs = snapshot.docs;

    if (newDocs.length < widget.limit) _hasMore = false;
    if (newDocs.isNotEmpty) _lastDoc = newDocs.last;

    setState(() {
      _docs.addAll(newDocs);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_docs.isEmpty) {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
      } else {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                widget.emptyMessage ?? 'No items found.',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        childAspectRatio: widget.childAspectRatio,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
      ),
      itemCount: _docs.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _docs.length) {
          return widget.itemBuilder(_docs[index]);
        } else {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}