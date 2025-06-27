// lazy_firestore_list.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LazyLoadingList extends StatefulWidget {
  final Query query;
  final Widget Function(DocumentSnapshot doc) itemBuilder;
  final int limit;
  final String? emptyMessage;

  const LazyLoadingList({
    super.key,
    required this.query,
    required this.itemBuilder,
    this.emptyMessage,
    this.limit = 10,
  });

  @override
  State<LazyLoadingList> createState() => _LazyLoadingListState();
}

class _LazyLoadingListState extends State<LazyLoadingList> {
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _docs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  String? emptyMessage;

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

              const SizedBox(height: 12),
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

    return ListView.builder(
      controller: _scrollController,
      itemCount: _docs.length + (_hasMore ? 1 : 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemBuilder: (context, index) {
        if (index < _docs.length) {
          return widget.itemBuilder(_docs[index]);
        } else {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
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
