import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/landing/presentation/pages/landing_page.dart';
import 'route_names.dart';
import 'route_paths.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.landing,
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
  ],
);

