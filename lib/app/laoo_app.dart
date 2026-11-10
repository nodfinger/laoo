import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/auth/app_auth_controller.dart';
import '../core/company_setup/company_setup_controller.dart';
import '../core/platform/window_title_service.dart';
import 'router/app_router.dart';
import 'router/app_menu_route_registry.dart';
import 'theme/laoo_theme.dart';
import 'theme/workspace_theme_presets.dart';
import '../features/assistant/assistant_launcher.dart';

/// Menu pages contain their own workspace shell. Avoid animating two shells
/// over one another on desktop, while leaving dialogs and other routes alone.
class _DesktopMenuTransitions extends PageTransitionsBuilder {
  const _DesktopMenuTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final name = route.settings.name;
    final menuPage =
        route.settings is Page &&
        name != null &&
        AppMenuRouteRegistry.all.any((entry) => entry.goRouteName == name);
    if (menuPage) return child;
    final PageTransitionsBuilder fallback =
        Theme.of(context).platform == TargetPlatform.macOS
        ? const CupertinoPageTransitionsBuilder()
        : const ZoomPageTransitionsBuilder();
    return fallback.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

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
        theme: LaooTheme.fromKey(LaooThemeKey.green).copyWith(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.windows: _DesktopMenuTransitions(),
              TargetPlatform.linux: _DesktopMenuTransitions(),
              TargetPlatform.macOS: _DesktopMenuTransitions(),
            },
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('th', 'TH'), Locale('en', 'US')],
        builder: (context, child) => AssistantLauncher(child: child!),
        routerConfig: appRouter,
      ),
    );
  }
}
