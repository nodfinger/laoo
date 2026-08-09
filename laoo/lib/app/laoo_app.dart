import 'package:flutter/material.dart';
import '../core/auth/app_auth_controller.dart';
import '../core/company_setup/company_setup_controller.dart';
import 'router/app_router.dart';
import 'theme/laoo_theme.dart';
import 'theme/workspace_theme_presets.dart';

class LaooApp extends StatefulWidget {
  const LaooApp({super.key});
  @override
  State<LaooApp> createState() => _LaooAppState();
}

class _LaooAppState extends State<LaooApp> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await workspaceThemeController.initialize();
    } catch (error) {
      debugPrint('Unable to restore workspace theme: $error');
    }

    await appAuthController.initialize();

    if (appAuthController.isAuthenticated) {
      try {
        await companySetupController.load();
      } catch (error) {
        debugPrint('Unable to load Company Setup: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: companySetupController,
      builder: (context, child) => MaterialApp.router(
        title: companySetupController.appTitle,
        debugShowCheckedModeBanner: false,
        theme: LaooTheme.fromKey(LaooThemeKey.green),
        routerConfig: appRouter,
      ),
    );
  }
}
