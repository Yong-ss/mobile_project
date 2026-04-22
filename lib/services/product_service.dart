import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class ProductService {
  static final _supabase = Supabase.instance.client;

  /// Deletes a product permanently, including related records in cart_item 
  /// and order_item (to satisfy FK constraints) and associated storage images.
  static Future<void> deleteProductComplete(dynamic productId, String? imageUrls) async {
    try {
      // 1. Delete from related tables to satisfy foreign key constraints
      // Note: This permanently removes these records from history.
      await _supabase.from('cart_item').delete().eq('product_id', productId);
      await _supabase.from('order_item').delete().eq('product_id', productId);

      // 2. Delete the product record itself
      await _supabase.from('product').delete().eq('id', productId);

      // 3. Cleanup associated images in storage
      if (imageUrls != null && imageUrls.isNotEmpty) {
        final urls = imageUrls.split(',');
        for (final url in urls) {
          final trimmedUrl = url.trim();
          if (trimmedUrl.isNotEmpty) {
            await deleteImageFromUrl(trimmedUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('Error in deleteProductComplete: $e');
      rethrow;
    }
  }

  /// Extracts bucket and path from a Supabase public URL and deletes the file.
  static Future<void> deleteImageFromUrl(String url) async {
    try {
      // Expected URL format: 
      // https://[project].supabase.co/storage/v1/object/public/[bucket]/[path]
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // Find 'public' segment to locate bucket and relative path
      final publicIndex = pathSegments.indexOf('public');
      if (publicIndex != -1 && pathSegments.length > publicIndex + 2) {
        final bucket = pathSegments[publicIndex + 1];
        // The rest of the segments form the file path within the bucket
        final path = pathSegments.sublist(publicIndex + 2).join('/');
        
        await _supabase.storage.from(bucket).remove([path]);
      }
    } catch (e) {
      // If image is already gone or URL is malformed, we just log it
      debugPrint('Failed to delete storage image: $url. Error: $e');
    }
  }
}
