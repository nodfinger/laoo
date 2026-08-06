import 'package:flutter/material.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/home/presentation/pages/authenticated_home_page.dart';
import '../features/landing/presentation/pages/landing_page.dart';

class LaooApp extends StatelessWidget {
  const LaooApp({super.key});

  static const String landingRoute = '/';
  static const String loginRoute = '/login';
  static const String homeRoute = '/home';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laoo Solutions',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF32C766),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7FAF8),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE7E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE7E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFF32C766),
              width: 1.5,
            ),
          ),
        ),
      ),
      initialRoute: landingRoute,
      routes: {
        landingRoute: (_) => const LandingPage(),
        loginRoute: (_) => const LoginPage(),
        homeRoute: (_) => const AuthenticatedHomePage(),
      },
    );
  }
}
