// lib/features/profile/presentation/controllers/profile_controller.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/profile_user_model.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/profile_repository.dart';
import '../../data/supabase_profile_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../curation/presentation/controllers/curation_controller.dart';
import '../../../feed/domain/models/feed_collection_model.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../domain/models/board_model.dart';
import '../../data/supabase_board_repository.dart';
import '../../domain/board_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository(Supabase.instance.client);
});

final boardRepositoryProvider = Provider<BoardRepository>((ref) {
  return SupabaseBoardRepository(Supabase.instance.client);
});

class ProfileState {
  const ProfileState({
    this.user,
    this.collections = const [],
    this.likedCollections = const [],
    this.bookmarkedCollections = const [],
    this.boards = const [],
    this.totalLikes = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.totalShotsCount = 0,
    this.isFollowing = false,
    this.hasMoreCollections = true,
    this.isLoadingMoreCollections = false,
  });

  final ProfileUserModel? user;
  final List<FeedCollectionModel> collections;
  final List<FeedCollectionModel> likedCollections;
  final List<FeedCollectionModel> bookmarkedCollections;
  final List<BoardModel> boards;
  final int totalLikes;
  final int followersCount;
  final int followingCount;
  final int totalShotsCount;
  final bool isFollowing;
  final bool hasMoreCollections;
  final bool isLoadingMoreCollections;

  ProfileState copyWith({
    ProfileUserModel? user,
    List<FeedCollectionModel>? collections,
    List<FeedCollectionModel>? likedCollections,
    List<FeedCollectionModel>? bookmarkedCollections,
    List<BoardModel>? boards,
    int? totalLikes,
    int? followersCount,
    int? followingCount,
    int? totalShotsCount,
    bool? isFollowing,
    bool? hasMoreCollections,
    bool? isLoadingMoreCollections,
  }) {
    return ProfileState(
      user: user ?? this.user,
      collections: collections ?? this.collections,
      likedCollections: likedCollections ?? this.likedCollections,
      bookmarkedCollections:
          bookmarkedCollections ?? this.bookmarkedCollections,
      boards: boards ?? this.boards,
      totalLikes: totalLikes ?? this.totalLikes,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      totalShotsCount: totalShotsCount ?? this.totalShotsCount,
      isFollowing: isFollowing ?? this.isFollowing,
      hasMoreCollections: hasMoreCollections ?? this.hasMoreCollections,
      isLoadingMoreCollections: isLoadingMoreCollections ?? this.isLoadingMoreCollections,
    );
  }
}

class ProfileController extends FamilyAsyncNotifier<ProfileState, String?> {
  @override
  Future<ProfileState> build(String? arg) async {
    return _fetchProfileData(arg);
  }

  Future<ProfileState> _fetchProfileData(String? targetUserId) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      return const ProfileState();
    }

    final userIdToFetch = targetUserId ?? currentUser.id;

    try {
      // Fetch user profile from 'users' table
      final userData = await supabase
          .from('users')
          .select()
          .eq('id', userIdToFetch)
          .single();

      final profileUser = ProfileUserModel.fromMap(userData);

      // Fetch user's collections (Limit 20 initially)
      final feedRepository = ref.read(feedRepositoryProvider);
      final isOwnProfile = userIdToFetch == currentUser.id;
      
      var collections = await feedRepository.getUserFeed(
        userIdToFetch,
        limit: 20,
        offset: 0,
      );

      // PRIVACY RULE: Filter private collections if not the owner (Safeguard)
      if (!isOwnProfile) {
        collections = collections.where((c) => !c.isPrivate).toList();
      }
      
      final bool hasMore = collections.length >= 20;

      // GET EXACT SHOTS COUNT
      int totalShotsCount = 0;
      try {
        var countQuery = supabase
            .from('collections')
            .select('id')
            .eq('user_id', userIdToFetch);
        
        if (!isOwnProfile) {
          countQuery = countQuery.eq('is_private', false);
        }
        
        final res = await countQuery.count(CountOption.exact);
        totalShotsCount = res.count;
      } catch (e) {
        debugPrint('[ProfileController] Error getting exact shots count: $e');
        totalShotsCount = collections.length;
      }

      // Fetch total likes received on current user's collections
      final collectionIds = collections.map((c) => c.collectionId).toList();
      int totalLikes = 0;
      if (collectionIds.isNotEmpty) {
        final likesResponse = await supabase
            .from('likes')
            .select('id')
            .inFilter('collection_id', collectionIds);
        totalLikes = (likesResponse as List).length;
      }

      // Fetch Follow Data
      final profileRepository = ref.read(profileRepositoryProvider);
      final followersCount = await profileRepository.getFollowersCount(
        userIdToFetch,
      );
      final followingCount = await profileRepository.getFollowingCount(
        userIdToFetch,
      );

      // Fetch Liked & Bookmarked Collections
      final likedCollections = await profileRepository.getUserLikedCollections(
        userIdToFetch,
      );

      // PRIVACY RULE: Bookmarks are only visible to the profile owner
      final bookmarkedCollections = isOwnProfile
          ? await profileRepository.getUserBookmarkedCollections(userIdToFetch)
          : <FeedCollectionModel>[];

      // Fetch Boards
      final boardRepository = ref.read(boardRepositoryProvider);
      final boards = await boardRepository.getUserBoards(userIdToFetch);

      final isFollowing = targetUserId != null && targetUserId != currentUser.id
          ? await profileRepository.checkIsFollowing(
              currentUser.id,
              targetUserId,
            )
          : false;

      return ProfileState(
        user: profileUser,
        collections: collections,
        likedCollections: likedCollections,
        bookmarkedCollections: bookmarkedCollections,
        boards: boards,
        totalLikes: totalLikes,
        followersCount: followersCount,
        followingCount: followingCount,
        totalShotsCount: totalShotsCount,
        isFollowing: isFollowing,
        hasMoreCollections: hasMore,
        isLoadingMoreCollections: false,
      );
    } catch (e) {
      debugPrint('[ProfileController] Error fetching profile data: $e');
      throw Exception('Failed to load profile data');
    }
  }

  Future<void> refreshProfile() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchProfileData(arg));
  }
  
  Future<void> loadMoreCollections() async {
    final currentState = state.value;
    if (currentState == null || currentState.user == null) return;
    if (currentState.isLoadingMoreCollections || !currentState.hasMoreCollections) return;

    final targetUserId = arg ?? Supabase.instance.client.auth.currentUser?.id;
    if (targetUserId == null) return;

    // Optimistically set loading state
    state = AsyncData(currentState.copyWith(isLoadingMoreCollections: true));

    try {
      final feedRepository = ref.read(feedRepositoryProvider);
      final offset = currentState.collections.length;
      final limit = 20;

      var additionalCollections = await feedRepository.getUserFeed(
        targetUserId,
        limit: limit,
        offset: offset,
      );

      final isOwnProfile = targetUserId == Supabase.instance.client.auth.currentUser?.id;
      if (!isOwnProfile) {
        additionalCollections = additionalCollections.where((c) => !c.isPrivate).toList();
      }

      final hasMore = additionalCollections.length >= limit;

      state = AsyncData(
        currentState.copyWith(
          collections: [...currentState.collections, ...additionalCollections],
          hasMoreCollections: hasMore,
          isLoadingMoreCollections: false,
        ),
      );
    } catch (e) {
      debugPrint('[ProfileController] Error loading more collections: $e');
      // Revert loading state
      state = AsyncData(currentState.copyWith(isLoadingMoreCollections: false));
    }
  }

  Future<void> toggleFollow() async {
    final currentState = state.value;
    if (currentState == null || currentState.user == null) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final targetUserId = currentState.user!.id;
    if (currentUserId == targetUserId) return; // Cannot follow yourself!

    final wasFollowing = currentState.isFollowing;
    final profileRepository = ref.read(profileRepositoryProvider);

    // Optimistic UI update
    state = AsyncData(
      currentState.copyWith(
        isFollowing: !wasFollowing,
        followersCount: currentState.followersCount + (wasFollowing ? -1 : 1),
      ),
    );

    try {
      await profileRepository.toggleFollow(
        currentUserId,
        targetUserId,
        wasFollowing,
      );
    } catch (e) {
      // Revert on failure
      state = AsyncData(currentState);
      debugPrint('[ProfileController] Error toggling follow: $e');
    }
  }

  Future<List<ProfileUserModel>> getFollowersList(String userId) async {
    final profileRepository = ref.read(profileRepositoryProvider);
    return await profileRepository.getFollowersList(userId);
  }

  Future<List<ProfileUserModel>> getFollowingList(String userId) async {
    final profileRepository = ref.read(profileRepositoryProvider);
    return await profileRepository.getFollowingList(userId);
  }

  Future<void> updateProfile({
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final updates = <String, dynamic>{};
      if (username != null) updates['username'] = username;
      if (bio != null) updates['bio'] = bio;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isEmpty) return;

      await Supabase.instance.client
          .from('users')
          .update(updates)
          .eq('id', currentUser.id);

      final currentState = state.value;
      if (currentState != null && currentState.user != null) {
        final updatedUser = ProfileUserModel(
          id: currentState.user!.id,
          username: username ?? currentState.user!.username,
          avatarUrl: avatarUrl ?? currentState.user!.avatarUrl,
          bio: bio ?? currentState.user!.bio,
        );
        state = AsyncData(currentState.copyWith(user: updatedUser));
      } else {
        await refreshProfile();
      }
    } catch (e) {
      debugPrint('[ProfileController] Error updating profile: $e');
      throw Exception('Failed to update profile');
    }
  }

  Future<void> uploadAvatar(File imageFile) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    state = const AsyncLoading(); // Feedback during upload

    try {
      // 1. Compress Image
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.absolute.path}/temp_avatar_${const Uuid().v4()}.jpg';
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 400,
        minHeight: 400,
      );

      if (compressedFile == null) throw Exception('Image compression failed');

      // 2. Upload to Supabase Storage
      final fileName =
          '${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('avatars')
          .upload(fileName, File(compressedFile.path));

      // 3. Get Public URL
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      // 4. Update users table & state
      await updateProfile(avatarUrl: publicUrl);
    } catch (e) {
      debugPrint('[ProfileController] Error uploading avatar: $e');
      // On error, just refresh the profile to clear the AsyncLoading state
      await refreshProfile();
      throw Exception('Failed to upload avatar');
    }
  }

  Future<void> createBoard({
    required String title,
    String? description,
    bool isPrivate = false,
    File? coverImage,
  }) async {
    final currentState = state.value;
    if (currentState == null || currentState.user == null) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      String? coverImageUrl;
      if (coverImage != null) {
        // Compress Image
        final dir = await getTemporaryDirectory();
        final targetPath =
            '${dir.absolute.path}/temp_board_cover_${const Uuid().v4()}.jpg';
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          coverImage.absolute.path,
          targetPath,
          quality: 70,
          minWidth: 800,
          minHeight: 800,
        );

        if (compressedFile == null) throw Exception('Image compression failed');

        // Upload to Supabase Storage -> 'boards' bucket
        final ext = 'jpg'; // We save as jpg after compression
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.$ext';
        final storagePath = '$currentUserId/$fileName';

        await Supabase.instance.client.storage
            .from('boards')
            .upload(storagePath, File(compressedFile.path));

        coverImageUrl = Supabase.instance.client.storage
            .from('boards')
            .getPublicUrl(storagePath);
      }

      final boardRepository = ref.read(boardRepositoryProvider);
      final newBoard = BoardModel(
        id: const Uuid().v4(), // Optimistic ID, Supabase ignores this on insert
        userId: currentUserId,
        title: title,
        description: description,
        coverImageUrl: coverImageUrl,
        isPrivate: isPrivate,
        createdAt: DateTime.now(),
      );

      final createdBoard = await boardRepository.createBoard(newBoard);

      // Update local state
      state = AsyncData(
        currentState.copyWith(boards: [createdBoard, ...currentState.boards]),
      );
    } catch (e) {
      debugPrint('[ProfileController] Error creating board: $e');
      throw Exception('Failed to create board');
    }
  }

  Future<void> updateBoard({
    required String boardId,
    String? title,
    String? description,
    bool? isPrivate,
    File? newCoverImage,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final boardIndex = currentState.boards.indexWhere((b) => b.id == boardId);
      if (boardIndex == -1) return;
      final existingBoard = currentState.boards[boardIndex];

      String? updatedCoverUrl = existingBoard.coverImageUrl;

      if (newCoverImage != null) {
        // Compress Image
        final dir = await getTemporaryDirectory();
        final targetPath =
            '${dir.absolute.path}/temp_board_cover_${const Uuid().v4()}.jpg';
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          newCoverImage.absolute.path,
          targetPath,
          quality: 70,
          minWidth: 800,
          minHeight: 800,
        );

        if (compressedFile != null) {
          final ext = 'jpg';
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.$ext';
          final storagePath = '$currentUserId/$fileName';

          await Supabase.instance.client.storage
              .from('boards')
              .upload(storagePath, File(compressedFile.path));

          updatedCoverUrl = Supabase.instance.client.storage
              .from('boards')
              .getPublicUrl(storagePath);
        }
      }

      final boardRepository = ref.read(boardRepositoryProvider);
      final updatedBoard = await boardRepository.updateBoard(
        BoardModel(
          id: existingBoard.id,
          userId: existingBoard.userId,
          title: title ?? existingBoard.title,
          description: description ?? existingBoard.description,
          coverImageUrl: updatedCoverUrl,
          isPrivate: isPrivate ?? existingBoard.isPrivate,
          createdAt: existingBoard.createdAt,
        ),
      );

      // Update local state by replacing the old board
      final newBoardsList = List<BoardModel>.from(currentState.boards);
      newBoardsList[boardIndex] = updatedBoard;

      state = AsyncData(currentState.copyWith(boards: newBoardsList));
    } catch (e) {
      debugPrint('[ProfileController] Error updating board: $e');
      throw Exception('Failed to update board');
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    ref.invalidate(authControllerProvider);
    ref.invalidate(feedControllerProvider);
    ref.invalidate(curationControllerProvider);
    ref.invalidateSelf();
  }
}

final profileControllerProvider =
    AsyncNotifierProviderFamily<ProfileController, ProfileState, String?>(
      ProfileController.new,
    );
