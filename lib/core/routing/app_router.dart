// lib/core/routing/app_router.dart
// LUMI — GoRouter with auth redirect guard.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/curation/presentation/screens/curation_screen.dart';
import '../../features/feed/domain/models/feed_collection_model.dart';
import '../../features/feed/presentation/screens/collection_detail_screen.dart';
import '../../features/feed/presentation/screens/discover_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/board_detail_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';

// ── Route name constants ──────────────────────────────────────────────────────

abstract final class AppRoutes {
  static const String splash = '/';
  static const String auth = '/auth';
  static const String feed = '/feed';
  static const String curation = '/curation';
  static const String profile = '/profile';
  static const String userProfile = '/profile/:id';
  static const String collectionDetail = '/collection/:id';
  static const String search = '/search';
  static const String boardDetail = '/board/:id/:name';
  static const String notifications = '/notifications';
}

// ── Router ────────────────────────────────────────────────────────────────────

final GoRouter appRouter = GoRouter(
  initialLocation:
      AppRoutes.feed, // Varsayılan açılış sayfası Feed (Guest Mode)
  debugLogDiagnostics: false,

  // ── Auth redirect guard ───────────────────────────────────────────────────
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    final isAuthRoute =
        state.uri.path == AppRoutes.splash || state.uri.path == AppRoutes.auth;

    // Giriş yapmış biri login sayfasına gelirse feed'e at
    if (isLoggedIn && isAuthRoute) return AppRoutes.feed;

    // Giriş YAPMAMIŞ fakat sadece giriş gerektiren bazı sayfalara gitmeye çalışıyorsa
    // (Örn: Curation veya kendi profiline gitme) onlara Login göster
    // Not: AppRoutes.feed, AppRoutes.search, collectionDetail misafire açık
    final isStrictProtectedRoute =
        state.uri.path == AppRoutes.curation ||
        state.uri.path == AppRoutes.profile ||
        state.uri.path == AppRoutes.notifications;

    if (!isLoggedIn && isStrictProtectedRoute) return AppRoutes.auth;

    return null; // allow through for Guest Mode
  },

  routes: [
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.auth,
      name: 'auth',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.feed,
      name: 'feed',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const DiscoverScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Slide in from left
          const begin = Offset(-1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.curation,
      name: 'curation',
      builder: (context, state) => const CurationScreen(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      name: 'profile',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const ProfileScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Slide in from right
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.userProfile,
      name: 'user-profile',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'];
        return CustomTransitionPage(
          key: state.pageKey,
          child: ProfileScreen(userId: id),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRoutes.search,
      name: 'search',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SearchScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Fade in for search
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.collectionDetail,
      name: 'collection-detail',
      builder: (context, state) {
        final collection = state.extra as FeedCollectionModel?;
        if (collection == null) {
          return const Scaffold(
            body: Center(child: Text('Collection not found')),
          );
        }
        return CollectionDetailScreen(collection: collection);
      },
    ),
    GoRoute(
      path: AppRoutes.boardDetail,
      name: 'board-detail',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final name = state.pathParameters['name']!;
        return BoardDetailScreen(boardId: id, boardName: name);
      },
    ),
    GoRoute(
      path: AppRoutes.notifications,
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0B),
    body: Center(
      child: Text(
        '404 — Page not found\n${state.error}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFE07070)),
      ),
    ),
  ),
);
