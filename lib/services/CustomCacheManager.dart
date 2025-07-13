import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomCacheManager {
  static CacheManager instance = CacheManager(
    Config(
      'customCacheKey',
      stalePeriod: const Duration(days: 4), // How long to keep files
      maxNrOfCacheObjects: 200,             // Max number of images
    ),
  );
}