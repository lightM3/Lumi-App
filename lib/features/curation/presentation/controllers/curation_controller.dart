// lib/features/curation/presentation/controllers/curation_controller.dart
// Riverpod AsyncNotifier — multi-photo curation logic.
// State tracks a list of selected photos + active index for ambient blur.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/custom_exceptions.dart';
import '../../../../core/utils/image_utils.dart';
import '../../data/supabase_curation_repository.dart';
import '../../domain/curation_repository.dart';
import '../../domain/models/collection_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class CurationState {
  const CurationState({
    this.selectedFiles = const [],
    this.glowColors = const {},
    this.activeIndex = 0,
    this.title = '',
    this.description = '',
    this.isPrivate = false,
  });

  /// All selected photo files.
  final List<File> selectedFiles;

  /// Dominant color per photo index (extracted asynchronously).
  final Map<int, Color> glowColors;

  /// Currently visible photo index in the PageView.
  final int activeIndex;

  final String title;
  final String description;
  final bool isPrivate;

  bool get hasPhotos => selectedFiles.isNotEmpty;

  /// Dominant color of the currently visible photo. Falls back to dark indigo.
  Color get activeGlowColor =>
      glowColors[activeIndex] ?? const Color(0xFF1A1A2E);

  CurationState copyWith({
    List<File>? selectedFiles,
    Map<int, Color>? glowColors,
    int? activeIndex,
    String? title,
    String? description,
    bool? isPrivate,
  }) {
    return CurationState(
      selectedFiles: selectedFiles ?? this.selectedFiles,
      glowColors: glowColors ?? this.glowColors,
      activeIndex: activeIndex ?? this.activeIndex,
      title: title ?? this.title,
      description: description ?? this.description,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }
}

// ── Repository Provider ───────────────────────────────────────────────────────

final curationRepositoryProvider = Provider<CurationRepository>(
  (_) => createSupabaseCurationRepository(),
);

// ── Controller ────────────────────────────────────────────────────────────────

class CurationController extends AsyncNotifier<CurationState> {
  CurationRepository get _repo => ref.read(curationRepositoryProvider);
  final _picker = ImagePicker();

  @override
  Future<CurationState> build() async => const CurationState();

  // ── Pick Multiple Images ──────────────────────────────────────────────────

  Future<void> pickImages() async {
    final List<XFile> picked = await _picker.pickMultiImage(
      imageQuality: 100, // we compress manually
    );
    if (picked.isEmpty) return;

    final files = picked.map((x) => File(x.path)).toList();
    final current = state.value ?? const CurationState();

    // Show selected images immediately
    state = AsyncData(
      current.copyWith(
        selectedFiles: [...current.selectedFiles, ...files],
        activeIndex: 0,
      ),
    );

    // Extract dominant colors for each new photo (non-blocking, parallel)
    _extractGlowColors(
      current.selectedFiles.length, // start offset
      files,
    );
  }

  /// Extracts dominant colors for [files] starting at [offset] index,
  /// then updates state with new colors as they resolve.
  Future<void> _extractGlowColors(int offset, List<File> files) async {
    for (int i = 0; i < files.length; i++) {
      try {
        final color = await ImageUtils.extractDominantColor(
          FileImage(files[i]),
        );
        final current = state.value;
        if (current == null) return;
        final updated = Map<int, Color>.from(current.glowColors);
        updated[offset + i] = color;
        state = AsyncData(current.copyWith(glowColors: updated));
      } catch (e) {
        // Keep default — colour extraction is cosmetic
        debugPrint('[CurationController] _extractGlowColors error: $e');
      }
    }
  }

  // ── Set Active Index (PageView page changed) ──────────────────────────────

  void setActiveIndex(int index) {
    final s = state.value;
    if (s == null || s.selectedFiles.isEmpty) return;
    // Clamp: the PageView has files.length + 1 items (Add More at end).
    // Never store an index that's out of selectedFiles bounds.
    final clamped = index.clamp(0, s.selectedFiles.length - 1);
    if (s.activeIndex == clamped) return;
    state = AsyncData(s.copyWith(activeIndex: clamped));
  }

  // ── Remove a photo ────────────────────────────────────────────────────────

  void removePhoto(int index) {
    final s = state.value;
    if (s == null) return;
    final updated = List<File>.from(s.selectedFiles)..removeAt(index);
    // Rebuild color map with shifted indices
    final updatedColors = <int, Color>{};
    for (final entry in s.glowColors.entries) {
      if (entry.key < index) {
        updatedColors[entry.key] = entry.value;
      } else if (entry.key > index) {
        updatedColors[entry.key - 1] = entry.value;
      }
    }
    final newActive = (s.activeIndex >= updated.length && updated.isNotEmpty)
        ? updated.length - 1
        : s.activeIndex;
    state = AsyncData(
      s.copyWith(
        selectedFiles: updated,
        glowColors: updatedColors,
        activeIndex: newActive,
      ),
    );
  }

  // ── Update title / description ────────────────────────────────────────────

  void updateTitle(String value) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(title: value));
  }

  void updateDescription(String value) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(description: value));
  }

  void updatePrivacy(bool value) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(isPrivate: value));
  }

  void reorderPhotos(int oldIndex, int newIndex) {
    final s = state.value;
    if (s == null) return;

    final files = List<File>.from(s.selectedFiles);
    final file = files.removeAt(oldIndex);
    files.insert(newIndex, file);

    // Reset colors and re-extract since order changed
    state = AsyncData(
      s.copyWith(selectedFiles: files, glowColors: {}, activeIndex: 0),
    );

    _extractGlowColors(0, files);
  }

  // ── Publish ───────────────────────────────────────────────────────────────

  Future<CollectionModel> publishCollection() async {
    debugPrint('[CurationController] publishCollection tetiklendi.');
    final s = state.value;

    if (s == null) {
      debugPrint('[CurationController] HATA: State null.');
      throw const UnexpectedException();
    }

    debugPrint(
      '[CurationController] Seçilen fotoğraf sayısı: \${s.selectedFiles.length}',
    );
    if (!s.hasPhotos) {
      debugPrint(
        '[CurationController] Validasyon Hatası: Fotoğraf seçilmemiş.',
      );
      throw const ValidationException('Please select at least one photo.');
    }

    debugPrint('[CurationController] Başlık: "\${s.title}"');
    debugPrint('[CurationController] Başlık: "${s.title}"');
    if (s.title.trim().isEmpty) {
      debugPrint('[CurationController] Validasyon Hatası: Başlık boş.');
      throw const ValidationException('Collection title cannot be empty.');
    }

    // Use Supabase directly to get fresh currentUser without Riverpod cache
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      debugPrint(
        '[CurationController] HATA: Kullanıcı oturumu kapalı (currentUser == null).',
      );
      throw const SessionExpiredException();
    }

    debugPrint(
      '[CurationController] Validasyonlar geçti. Storage/DB işlemine başlanıyor. Yükleme durumuna geçiliyor...',
    );
    state = const AsyncLoading();

    try {
      final collection = await _repo.createCollection(
        userId: currentUser.id,
        title: s.title.trim(),
        description: s.description.trim().isEmpty ? null : s.description.trim(),
        photos: s.selectedFiles,
        isPrivate: s.isPrivate,
      );

      debugPrint(
        '[CurationController] BAŞARILI: Koleksiyon ve fotoğraflar kaydedildi.',
      );
      state = const AsyncData(CurationState()); // reset
      return collection;
    } on LumiException catch (e) {
      debugPrint('[CurationController] Gerçek Hata: $e');
      state = AsyncData(s);
      rethrow;
    } catch (e, st) {
      debugPrint('[CurationController] Gerçek Hata: $e');
      debugPrint('[CurationController] Stacktrace: $st');
      state = AsyncData(s);
      throw UnexpectedException(cause: e);
    }
  }

  void reset() => state = const AsyncData(CurationState());
}

final curationControllerProvider =
    AsyncNotifierProvider<CurationController, CurationState>(
      CurationController.new,
    );
