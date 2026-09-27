import 'package:flutter/material.dart';

import '../core/company_setup/company_setup_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_key.dart';

class LaooApp extends StatelessWidget {
  const LaooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: companySetupController,
      builder: (context, child) {
        return MaterialApp.router(
          title: companySetupController.appTitle,
          debugShowCheckedModeBanner: false,

          // Theme stays on the current safe fallback until the exact
          // TDSTCompanySetUp theme field name is approved.
          // The runtime contract already supports themeCode.
          theme: AppTheme.fromKey(AppThemeKey.green),
          routerConfig: appRouter,
        );
      },
    );
  }
}
