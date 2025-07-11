// Updated PersonalizedRecommendationsWidget
import 'package:flutter/material.dart';

import '../../services/recommendation_service.dart';

class PersonalizedRecommendationsWidget extends StatefulWidget {
  final Function(String) onProductTap;
  final bool showDebugInfo;

  const PersonalizedRecommendationsWidget({
    Key? key,
    required this.onProductTap,
    this.showDebugInfo = false,
  }) : super(key: key);

  @override
  State<PersonalizedRecommendationsWidget> createState() =>
      _PersonalizedRecommendationsWidgetState();
}

class _PersonalizedRecommendationsWidgetState
    extends State<PersonalizedRecommendationsWidget> {
  final PersonalizedRecommendationService _service =
      PersonalizedRecommendationService();

  bool _isGenerating = false;
  String _status = '';

  // Add these to cache the future and prevent rebuilds
  Future<List<PersonalizedRecommendation>>? _recommendationsFuture;
  List<PersonalizedRecommendation>? _cachedRecommendations;

  @override
  void initState() {
    super.initState();
    _initializeRecommendations();
  }

  Future<void> _initializeRecommendations() async {
    // Create the future once and cache it
    _recommendationsFuture = _loadRecommendations();
  }

  Future<List<PersonalizedRecommendation>> _loadRecommendations() async {
    // Check if user has recommendations
    final hasRecs = await _service.hasRecommendations();

    if (!hasRecs) {
      setState(() {
        _status = 'Generating your personalized recommendations...';
        _isGenerating = true;
      });

      // Generate recommendations for new users
      await _service.generateRecommendations(showProgress: true);

      setState(() {
        _isGenerating = false;
        _status = '';
      });
    }

    // Get recommendations and cache them
    final recommendations = await _service.getPersonalizedRecommendations();
    _cachedRecommendations = recommendations;
    return recommendations;
  }


  Future<void> _refreshRecommendations() async {
    setState(() {
      _isGenerating = true;
      _status = 'Updating recommendations...';
    });

    _service.clearCache();
    await _service.generateRecommendations(showProgress: true);

    // Create new future and update cache
    _recommendationsFuture = _service.getPersonalizedRecommendations();
    _cachedRecommendations = await _recommendationsFuture!;

    setState(() {
      _isGenerating = false;
      _status = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showDebugInfo) _buildDebugInfo(),
        if (_isGenerating) _buildGeneratingWidget(),
        if (!_isGenerating) _buildRecommendationsWidget(),
      ],
    );
  }

  Widget _buildDebugInfo() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _service.getRecommendationStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final stats = snapshot.data!;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Debug Info:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Total Views: ${stats['totalViews']}'),
              Text('Total Purchases: ${stats['totalPurchases']}'),
              Text('Recommendations: ${stats['totalRecommendations']}'),
              Text('Based on Views: ${stats['basedOnViews']}'),
              Text('Based on Purchases: ${stats['basedOnPurchases']}'),
              if (stats['lastGenerated'] != null)
                Text('Last Generated: ${stats['lastGenerated']}'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGeneratingWidget() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _status,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a few moments...',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsWidget() {
    // Use the cached future to prevent rebuilds
    return FutureBuilder<List<PersonalizedRecommendation>>(
      future: _recommendationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoRecommendations();
        }

        final recommendations = snapshot.data!;
        return _buildRecommendationsList(recommendations);
      },
    );
  }


  Widget _buildRecommendationsList(
    List<PersonalizedRecommendation> recommendations,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recommended for You',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Row(
                children: [
                  if (widget.showDebugInfo)
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => _showStatsDialog(),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refreshRecommendations,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final rec = recommendations[index];
              return _buildRecommendationCard(rec);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(PersonalizedRecommendation rec) {
    return GestureDetector(
      onTap: () {
        // Track the view
        _service.trackProductView(rec.productId);
        // Navigate to product
        widget.onProductTap(rec.productId);
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                rec.productURL,
                height: 160,
                width: 160,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 160,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Product Name
            Text(
              rec.productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            // Price
            Text(
              'RM ${rec.productPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            // Recommendation Reason
            Text(
              rec.reason,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            if (widget.showDebugInfo)
              Text(
                'Score: ${rec.similarityScore.toStringAsFixed(3)}',
                style: TextStyle(fontSize: 10, color: Colors.red[600]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRecommendations() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.recommend_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No recommendations yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse more products to get personalized recommendations',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshRecommendations,
              child: const Text('Generate Recommendations'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Error loading recommendations',
              style: TextStyle(fontSize: 18, color: Colors.red[600]),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recommendation Stats'),
        content: FutureBuilder<Map<String, dynamic>>(
          future: _service.getRecommendationStats(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            final stats = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Recommendations: ${stats['totalRecommendations']}'),
                Text('Based on Views: ${stats['basedOnViews']}'),
                Text('Based on Purchases: ${stats['basedOnPurchases']}'),
                Text('Your Total Views: ${stats['totalViews']}'),
                Text('Your Total Purchases: ${stats['totalPurchases']}'),
                if (stats['lastGenerated'] != null)
                  Text('Last Generated: ${stats['lastGenerated']}'),
                Text('Version: ${stats['version']}'),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
