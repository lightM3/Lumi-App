// lib/features/comment/domain/repositories/comment_repository_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/supabase_comment_repository.dart';
import 'comment_repository.dart';

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return SupabaseCommentRepository(Supabase.instance.client);
});
