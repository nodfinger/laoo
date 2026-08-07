import 'package:flutter/material.dart';
import '../core/auth/app_auth_controller.dart';
import 'router/app_router.dart';
import 'theme/laoo_theme.dart';

class LaooApp extends StatefulWidget {
  const LaooApp({super.key});
  @override
  State<LaooApp> createState() => _LaooAppState();
}

class _LaooAppState extends State<LaooApp> {
  @override
  void initState() {
    super.initState();
    appAuthController.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Laoo Solutions',
      debugShowCheckedModeBanner: false,
      theme: LaooTheme.fromKey(LaooThemeKey.green),
      routerConfig: appRouter,
    );
  }
}
