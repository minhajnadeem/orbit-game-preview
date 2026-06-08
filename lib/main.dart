import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'app_config.dart';
import 'theme/app_theme.dart';
import 'views/landing_view.dart';
import 'views/admin_view.dart';
import 'views/host_view.dart';
import 'views/player_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  runApp(const ProviderScope(child: MyApp()));
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LandingView(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminView(),
    ),
    GoRoute(
      path: '/host',
      builder: (context, state) => const HostView(),
    ),
    GoRoute(
      path: '/player',
      builder: (context, state) {
        final slotStr = state.uri.queryParameters['slot'];
        final slot = slotStr != null ? int.tryParse(slotStr) : null;
        return PlayerView(slot: slot);
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
