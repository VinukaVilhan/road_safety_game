import 'package:flutter/widgets.dart';

import '../../constants/media_assets.dart';

/// Service to preload images used in the app to avoid loading delays during navigation
class ImagePreloader {
  static final Map<String, ImageProvider> _preloadedImages = {};
  static bool _isPreloading = false;
  
  /// Preload all critical images used in the app
  /// Note: This should be called with a BuildContext from a widget tree
  static Future<void> preloadImages(BuildContext? context) async {
    if (_isPreloading || context == null) return;
    _isPreloading = true;
    
    final images = [
      MediaAssets.steeringWheelRescaled,
      MediaAssets.gearboxCubicRescaled,
      MediaAssets.gasNormalRescaled,
      MediaAssets.gasPressedRescaled,
      MediaAssets.gasPressedSimpleRescaled,
      MediaAssets.brakeNormalRescaled,
      MediaAssets.brakePressedRescaled,
      MediaAssets.brakePressedSimpleRescaled,
    ];
    
    for (final path in images) {
      try {
        final provider = AssetImage(path);
        _preloadedImages[path] = provider;
        // Preload into cache - requires BuildContext
        await precacheImage(provider, context);
      } catch (e) {
        // Silently fail for missing images - they'll use errorBuilder
        debugPrint('Failed to preload image: $path - $e');
      }
    }
    
    _isPreloading = false;
  }
  
  /// Get a preloaded image provider if available
  static ImageProvider? getPreloadedImage(String path) {
    return _preloadedImages[path];
  }
  
  /// Check if an image has been preloaded
  static bool isPreloaded(String path) {
    return _preloadedImages.containsKey(path);
  }
}

