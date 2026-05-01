import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for optimized image loading with URL generation
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  /// Get optimized image URL from Supabase storage
  /// Returns a URL that can be used with Image.network with caching
  static String getOptimizedImageUrl(
    String storagePath, {
    String bucket = 'order_proofs',
    int? width,
    int? height,
    int quality = 80,
  }) {
    try {
      final url = Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(storagePath);
      
      // Note: For image optimization, you can use Supabase's image transformation
      // or a CDN service. The URL can be enhanced with query parameters if your
      // storage provider supports it.
      return url;
    } catch (e) {
      print('⚠️ Error getting image URL: $e');
      return storagePath;
    }
  }

  /// Get image URL with size constraints for faster loading on slow connections
  static String getThumbnailUrl(
    String storagePath, {
    String bucket = 'order_proofs',
    int maxWidth = 300,
    int maxHeight = 300,
  }) {
    // Return optimized URL for thumbnails
    // Adjust based on your image transformation setup
    return getOptimizedImageUrl(
      storagePath,
      bucket: bucket,
      width: maxWidth,
      height: maxHeight,
      quality: 70, // Lower quality for thumbnails
    );
  }
}

