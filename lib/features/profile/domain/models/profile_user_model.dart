// lib/features/profile/domain/models/profile_user_model.dart

class ProfileUserModel {
  const ProfileUserModel({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.bio,
  });

  final String id;
  final String username;
  final String? avatarUrl;
  final String? bio;

  factory ProfileUserModel.fromMap(Map<String, dynamic> map) {
    return ProfileUserModel(
      id: map['id'] as String,
      username: map['username'] as String,
      avatarUrl: map['avatar_url'] as String?,
      bio: map['bio'] as String?,
    );
  }
}
