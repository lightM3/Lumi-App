import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/comment_model.dart';

final activeReplyProvider = StateProvider<CommentModel?>((ref) => null);
