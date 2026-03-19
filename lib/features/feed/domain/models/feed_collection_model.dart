// lib/features/feed/domain/models/feed_collection_model.dart
// Pure Dart model representing a single card in the Discover Feed.
// It joins data from `collections`, `photos`, and `users` tables.

class FeedPhotoItem {
  const FeedPhotoItem({
    required this.id,
    required this.imageUrl,
    required this.aspectRatio,
  });

  final String id;
  final String imageUrl;
  final double aspectRatio;

  factory FeedPhotoItem.fromMap(Map<String, dynamic> map) {
    return FeedPhotoItem(
      id: map['id'] as String,
      imageUrl: map['image_url'] as String,
      aspectRatio: (map['aspect_ratio'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class FeedCollectionModel {
  const FeedCollectionModel({
    required this.collectionId,
    required this.title,
    required this.coverImageUrl,
    required this.aspectRatio,
    required this.photos,
    this.description,
    this.dominantColor,
    required this.userId,
    required this.authorUsername,
    this.authorAvatarUrl,
    required this.createdAt,
    this.likeCount = 0,
    this.isLiked = false,
    this.isBookmarked = false,
    this.isPrivate = false,
  });

  final String collectionId;
  final String title;
  final String coverImageUrl;
  final double aspectRatio;
  final List<FeedPhotoItem> photos; // All photos for the detail screen
  final String? description; // Optional description
  final String? dominantColor; // Hex string, e.g. "#6C4FCA"
  final String userId; // Owner ID
  final String authorUsername;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final int likeCount;
  final bool isLiked;
  final bool isBookmarked;
  final bool isPrivate;

  FeedCollectionModel copyWith({
    String? collectionId,
    String? title,
    String? coverImageUrl,
    double? aspectRatio,
    List<FeedPhotoItem>? photos,
    String? description,
    String? dominantColor,
    String? userId,
    String? authorUsername,
    String? authorAvatarUrl,
    DateTime? createdAt,
    int? likeCount,
    bool? isLiked,
    bool? isBookmarked,
    bool? isPrivate,
  }) {
    return FeedCollectionModel(
      collectionId: collectionId ?? this.collectionId,
      title: title ?? this.title,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      photos: photos ?? this.photos,
      description: description ?? this.description,
      dominantColor: dominantColor ?? this.dominantColor,
      userId: userId ?? this.userId,
      authorUsername: authorUsername ?? this.authorUsername,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }

  /// Factory method to parse the JOINed response from Supabase.
  factory FeedCollectionModel.fromMap(
    Map<String, dynamic> map, {
    String? currentUserId,
  }) {
    // 1. Extract Collection data
    final collectionId = map['id'] as String;
    final userId = map['user_id'] as String;
    final title = map['title'] as String;
    final description = map['description'] as String?;
    final dominantColor = map['dominant_color'] as String?;
    final isPrivate = map['is_private'] as bool? ?? false;
    final createdAt = DateTime.parse(map['created_at'] as String);

    // 2. Extract Photos
    final photosList = map['photos'] as List<dynamic>? ?? [];
    String coverImageUrl = '';
    double aspectRatio = 1.0;
    final parsedPhotos = <FeedPhotoItem>[];

    if (photosList.isNotEmpty) {
      // Assuming photosList is already sorted by sort_order
      for (final p in photosList) {
        if (p is Map<String, dynamic>) {
          parsedPhotos.add(FeedPhotoItem.fromMap(p));
        }
      }

      if (parsedPhotos.isNotEmpty) {
        coverImageUrl = parsedPhotos.first.imageUrl;
        aspectRatio = parsedPhotos.first.aspectRatio;
      }
    }

    // 3. Extract User data
    final userMap = map['users'] as Map<String, dynamic>?;
    final username = userMap?['username'] as String? ?? 'user';
    final avatarUrl = userMap?['avatar_url'] as String?;

    // 4. Extract Likes
    int likeCount = 0;
    bool isLiked = false;

    if (map['likes'] != null) {
      final likesData = map['likes'];
      if (likesData is List) {
        // If it's a list, it might be the full list of likes or just the user's like
        // We handle count via a count query or array length, but PostgREST usually returns array
        // We'll calculate it based on what Supabase returns

        // Actually, for count, supabase often returns [{count: 10}] if we ask for count,
        // but if we do likes(user_id) it returns a list of objects.
        // The exact parsing depends on the query. We'll handle a list of likes:

        // wait, usually we want exact count. Let's assume the query returns array of all likes
        // Or if we specify likes(user_id), it only returns the matching row for the current user.
        // Let's assume we fetch `likes(user_id)` to check if liked, and maybe a separate count.
        // Let's refine parsing:
      } else if (likesData is Map) {
        // Handle exact count object if needed.
      }
    }
    // We will parse properly in fromMap later based on how we query.
    // Let's define the generic parsing:
    if (map['likes'] is List) {
      // If we query `likes(user_id)` it only returns rows if the user liked it.
      // So if list is not empty, it means the user liked it!
      // But wait, what about total count?
      // In Supabase, getting count AND a specific condition on the same join is tricky.
      // A common way: `likes!inner(user_id)` (filters parent) or just `likes(user_id)`.
      // The total count is usually retrieved with `likes!count()`.
      // We will parse `like_count` if it exists, otherwise fall back to list length.
    }

    // Safer generic approach:
    if (map.containsKey('like_count')) {
      likeCount = map['like_count'] as int? ?? 0;
    } else if (map['likes'] is List) {
      // Temporary fallback
      likeCount = (map['likes'] as List).length;
    }

    // Check if the current user liked it
    if (currentUserId != null && map['likes'] is List) {
      final likesList = map['likes'] as List;
      isLiked = likesList.any((like) {
        return like is Map && like['user_id'] == currentUserId;
      });
    }

    // Check if the current user bookmarked it
    bool isBookmarked = false;
    if (currentUserId != null && map['bookmarks'] is List) {
      final bookmarksList = map['bookmarks'] as List;
      isBookmarked = bookmarksList.any((bookmark) {
        return bookmark is Map && bookmark['user_id'] == currentUserId;
      });
    }

    return FeedCollectionModel(
      collectionId: collectionId,
      title: title,
      coverImageUrl: coverImageUrl,
      aspectRatio: aspectRatio,
      photos: parsedPhotos,
      description: description,
      dominantColor: dominantColor,
      userId: userId,
      authorUsername: username,
      authorAvatarUrl: avatarUrl,
      createdAt: createdAt,
      likeCount: likeCount,
      isLiked: isLiked,
      isBookmarked: isBookmarked,
      isPrivate: isPrivate,
    );
  }
}
