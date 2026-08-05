import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_key.dart';

class LaooApp extends StatelessWidget {
  const LaooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Laoo Solutions',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromKey(AppThemeKey.green),
      routerConfig: appRouter,
    );
  }
}
