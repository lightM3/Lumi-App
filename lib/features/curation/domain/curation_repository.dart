// lib/features/curation/domain/curation_repository.dart
// Abstract interface — presentation never imports Supabase directly.

import 'dart:io';
import 'models/collection_model.dart';

abstract interface class CurationRepository {
  /// Creates a new collection with multiple photos.
  ///
  /// Pipeline:
  ///   1. Compress all [photos] in background (flutter_image_compress)
  ///   2. Extract aspect ratio for each photo (compute/isolate)
  ///   3. Upload all compressed photos to Supabase Storage
  ///   4. Extract dominant color from cover (first) photo
  ///   5. Insert row into `collections` table (cover = photos[0])
  ///   6. Insert rows into `photos` table (one per photo)
  ///
  /// Returns the created [CollectionModel].
  /// Throws [StorageUploadException] or [DatabaseException] on failure.
  Future<CollectionModel> createCollection({
    required String userId,
    required String title,
    String? description,
    required List<File> photos, // photos[0] = cover image
    bool isPrivate = false,
  });
}
