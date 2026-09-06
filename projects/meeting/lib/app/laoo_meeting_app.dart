import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/auth/app_auth_controller.dart';
import '../core/company_setup/company_setup_controller.dart';
import '../core/platform/window_title_service.dart';
import 'router/app_router.dart';
import 'theme/laoo_theme.dart';
import 'theme/workspace_theme_presets.dart';

class LaooMeetingApp extends StatefulWidget {
  const LaooMeetingApp({super.key});
  @override
  State<LaooMeetingApp> createState() => _LaooMeetingAppState();
}

class _LaooMeetingAppState extends State<LaooMeetingApp> {
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
          WindowTitleService.setTitle(companySetupController.appTitle);
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
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('th', 'TH'),
          Locale('en', 'US'),
        ],
        routerConfig: appRouter,
      ),
    );
  }
}
