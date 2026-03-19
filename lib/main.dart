import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/supabase_config.dart';
import 'core/providers/storage_providers.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 0. Localizations ───────────────────────────────────────────────────────
  timeago.setLocaleMessages('tr', timeago.TrMessages());

  // ── 1. Load environment variables ──────────────────────────────────────────
  await dotenv.load(fileName: '.env');

  // ── 2. Force portrait mode (can be unlocked per-screen if needed) ──────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── 3. Immersive edge-to-edge UI ───────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // ── 4. Initialise Supabase ─────────────────────────────────────────────────
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    // AuthFlowType.implicit is required for mobile OAuth deep link callbacks.
    // The default PKCE flow exchanges a code that can't be intercepted by a
    // custom URL scheme (io.lumi://), so the browser stays open and falls back
    // to localhost. Implicit flow completes entirely via the deep link redirect.
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // ── 5. Initialise SharedPreferences ────────────────────────────────────────
  final sharedPrefs = await SharedPreferences.getInstance();

  // ── 6. Run app ─────────────────────────────────────────────────────────────
  runApp(
    // ProviderScope is the root of the Riverpod provider tree.
    // All feature providers (auth, feed, curation, profile) live under here.
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      child: const LumiApp(),
    ),
  );
}

class LumiApp extends StatefulWidget {
  const LumiApp({super.key});

  @override
  State<LumiApp> createState() => _LumiAppState();
}

class _LumiAppState extends State<LumiApp> {
  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    // ── Global Auth State Listener ──
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) {
          final AuthChangeEvent event = data.event;
          if (event == AuthChangeEvent.signedOut) {
            // Force redirect to login screen when signed out
            appRouter.go(AppRoutes.auth);
          }
        });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Lumi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
