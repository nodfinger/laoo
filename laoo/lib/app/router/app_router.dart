import 'package:go_router/go_router.dart';

import '../../core/auth/app_auth_controller.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/landing/presentation/pages/landing_page.dart';
import '../../features/support/partner/pages/partner_module_page.dart';
import '../../features/support/company_setup/pages/company_setup_page.dart';
import '../../features/support/presentation/pages/support_home_page.dart';
import '../../features/support/presentation/pages/support_placeholder_page.dart';
import '../../features/support/presentation/widgets/support_workspace_shell.dart';
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
    ..._placeholderRoutes,
    GoRoute(
      path: RoutePaths.companySetup,
      name: RouteNames.companySetup,
      builder: (context, state) => SupportWorkspaceShell(
        pageTitle: 'กำหนดค่าระบบ',
        activeMenu: 'companySetup',
        child: CompanySetupPage(),
      ),
    ),
  ],
);

final List<GoRoute> _placeholderRoutes = [
  _placeholder(RoutePaths.company, RouteNames.company, 'Company', 'company'),
  _placeholder(RoutePaths.branch, RouteNames.branch, 'Branch', 'branch'),
  _placeholder(RoutePaths.laooUser, RouteNames.laooUser, 'Laoo User', 'laooUser'),
  _placeholder(RoutePaths.partnerUser, RouteNames.partnerUser, 'Partner User', 'partnerUser'),
  _placeholder(RoutePaths.companyUser, RouteNames.companyUser, 'Company User', 'companyUser'),
  _placeholder(RoutePaths.module, RouteNames.module, 'Module', 'module'),
  _placeholder(RoutePaths.customerModule, RouteNames.customerModule, 'Customer Module', 'customerModule'),
  _placeholder(RoutePaths.permission, RouteNames.permission, 'Role / Permission', 'permission'),
  _placeholder(RoutePaths.audit, RouteNames.audit, 'Audit Log', 'audit'),
  _placeholder(RoutePaths.loginLog, RouteNames.loginLog, 'Login Log', 'loginLog'),
];

GoRoute _placeholder(
  String path,
  String name,
  String title,
  String activeMenu,
) {
  return GoRoute(
    path: path,
    name: name,
    builder: (context, state) => SupportPlaceholderPage(
      title: title,
      activeMenu: activeMenu,
    ),
  );
}
