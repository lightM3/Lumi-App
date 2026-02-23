// lib/features/auth/domain/models/lumi_user.dart
// Domain model — keeps presentation layer decoupled from Supabase types.

class LumiUser {
  const LumiUser({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String? avatarUrl;
  final DateTime createdAt;

  /// Construct from Supabase `users` table row.
  factory LumiUser.fromMap(Map<String, dynamic> map) {
    return LumiUser(
      id: map['id'] as String,
      username: map['username'] as String,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'id': id,
    'username': username,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
  };

  @override
  String toString() => 'LumiUser(id: $id, username: $username)';
}
