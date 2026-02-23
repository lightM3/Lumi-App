// lib/features/curation/data/supabase_curation_repository.dart
// Supabase implementation of CurationRepository.
// Multi-photo pipeline: compress all → upload all → extract cover color → DB insert

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_config.dart';
import '../../../core/error/custom_exceptions.dart';
import '../../../core/utils/image_utils.dart';
import '../domain/curation_repository.dart';
import '../domain/models/collection_model.dart';
import '../domain/models/photo_model.dart';

final class SupabaseCurationRepository implements CurationRepository {
  SupabaseCurationRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<CollectionModel> createCollection({
    required String userId,
    required String title,
    String? description,
    required List<File> photos,
    bool isPrivate = false,
  }) async {
    assert(photos.isNotEmpty, 'photos must not be empty');

    // ── Step 1 & 2: Compress all + extract aspect ratios (parallel) ───────────
    final List<_ProcessedPhoto> processed = await Future.wait(
      photos.map(_processPhoto),
    );

    // ── Step 3: Upload all to Supabase Storage ────────────────────────────────
    final String prefix = '$userId/${DateTime.now().millisecondsSinceEpoch}';
    final List<String> imageUrls = [];

    for (int i = 0; i < processed.length; i++) {
      final path = '$prefix/$i.jpg';
      try {
        await _supabase.storage
            .from(SupabaseConfig.curationsStorageBucket)
            .uploadBinary(
              path,
              processed[i].compressed,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );
        imageUrls.add(
          _supabase.storage
              .from(SupabaseConfig.curationsStorageBucket)
              .getPublicUrl(path),
        );
      } catch (e) {
        throw StorageUploadException(
          'Failed to upload photo ${i + 1} of ${photos.length}.',
          cause: e,
        );
      }
    }

    // ── Step 4: Dominant color from cover (first) image ───────────────────────
    String? dominantColorHex;
    try {
      final color = await ImageUtils.extractDominantColor(
        NetworkImage(imageUrls.first),
      );
      dominantColorHex = ImageUtils.colorToHex(color);
    } catch (_) {
      // Non-fatal: cosmetic only
    }

    // ── Step 5: Insert into `collections` table ────────────────────────────────
    final CollectionModel collection;
    try {
      final draft = CollectionModel(
        id: '',
        userId: userId,
        title: title,
        description: description,
        dominantColor: dominantColorHex,
        isPrivate: isPrivate,
        createdAt: DateTime.now(),
      );

      final response = await _supabase
          .from(SupabaseConfig.collectionsTable)
          .insert(draft.toInsertMap())
          .select()
          .single();

      collection = CollectionModel.fromMap(response);
    } catch (e) {
      throw DatabaseException('Failed to save collection metadata.', cause: e);
    }

    // ── Step 6: Insert into `photos` table (all photos) ───────────────────────
    try {
      final photoRows = List.generate(imageUrls.length, (i) {
        // Find the relative storage path to store in DB
        // Format: {userId}/{timestamp}/{index}.jpg
        final path = '$prefix/$i.jpg';

        return PhotoModel(
          id: '',
          collectionId: collection.id,
          userId: userId,
          imageUrl: imageUrls[i],
          storagePath: path,
          aspectRatio: processed[i].aspectRatio,
          sortOrder: i,
          createdAt: DateTime.now(),
        ).toInsertMap();
      });

      await _supabase.from(SupabaseConfig.photosTable).insert(photoRows);
    } catch (e) {
      // Non-fatal: collection exists — supplementary photo rows
      debugPrint('[CurationRepository] photos insert failed (non-fatal): $e');
    }

    return collection;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<_ProcessedPhoto> _processPhoto(File file) async {
    final compressed = await ImageUtils.compressImage(file);
    final aspectRatio = await ImageUtils.extractAspectRatio(compressed);
    return _ProcessedPhoto(compressed: compressed, aspectRatio: aspectRatio);
  }
}

class _ProcessedPhoto {
  const _ProcessedPhoto({required this.compressed, required this.aspectRatio});
  final Uint8List compressed;
  final double aspectRatio;
}

// ── Factory ───────────────────────────────────────────────────────────────────

SupabaseCurationRepository createSupabaseCurationRepository() =>
    SupabaseCurationRepository(Supabase.instance.client);
