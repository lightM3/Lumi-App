// lib/features/profile/presentation/controllers/collection_board_membership_controller.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_controller.dart';

class CollectionBoardMembershipController
    extends FamilyAsyncNotifier<List<String>, String> {
  @override
  FutureOr<List<String>> build(String arg) async {
    final repository = ref.read(boardRepositoryProvider);
    return repository.getBoardIdsForCollection(arg);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      final repository = ref.read(boardRepositoryProvider);
      return repository.getBoardIdsForCollection(arg);
    });
  }
}

final collectionBoardMembershipProvider =
    AsyncNotifierProviderFamily<
      CollectionBoardMembershipController,
      List<String>,
      String
    >(CollectionBoardMembershipController.new);
