import 'package:flutter/material.dart';

import 'features/landing/presentation/pages/landing_page.dart';

class LaooApp extends StatelessWidget {
  const LaooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laoo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7FAF7),
      ),
      home: const LandingPage(),
    );
  }
}
