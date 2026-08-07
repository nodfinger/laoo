import 'package:go_router/go_router.dart';

import '../../core/auth/app_auth_controller.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/landing/presentation/pages/landing_page.dart';
import '../../features/support/partner/pages/partner_module_page.dart';
import '../../features/support/presentation/pages/support_home_page.dart';
import 'route_names.dart';
import 'route_paths.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.landing,
  refreshListenable: appAuthController,
  redirect: (context, state) {
    final path = state.uri.path;

    if (appAuthController.isChecking) {
      return null;
    }

    final isSupportRoute =
        path == RoutePaths.supportHome ||
        path.startsWith('${RoutePaths.supportHome}/');

    if (!appAuthController.isAuthenticated) {
      if (isSupportRoute) {
        return RoutePaths.login;
      }
      return null;
    }

    // Support Workspace is reserved for Laoo Support users.
    if (isSupportRoute && !appAuthController.isLaooSupport) {
      return RoutePaths.login;
    }

    // Authenticated Laoo Support users should not remain on Login.
    if (path == RoutePaths.login && appAuthController.isLaooSupport) {
      return RoutePaths.supportHome;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: RoutePaths.landing,
      name: RouteNames.landing,
      builder: (context, state) => const LandingPage(),
    ),
    GoRoute(
      path: RoutePaths.login,
      name: RouteNames.login,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: RoutePaths.supportHome,
      name: RouteNames.supportHome,
      builder: (context, state) => const SupportHomePage(),
    ),
    GoRoute(
      path: RoutePaths.partner,
      name: RouteNames.partner,
      builder: (context, state) => const PartnerModulePage(),
    ),
  ],
);
