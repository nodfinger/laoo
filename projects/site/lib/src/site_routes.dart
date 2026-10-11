import 'package:go_router/go_router.dart';
import 'site_screen.dart';
import 'site_customer_portal_page.dart';

class SiteRoute {
  const SiteRoute(this.menuCode, this.routeName);
  final String menuCode;
  final String routeName;
  String get routePath => '/company/$routeName';
}

abstract final class SiteRoutes {
  static const all = <SiteRoute>[
    SiteRoute('63001', 'site-settings'),
    SiteRoute('63002', 'site-projects'),
    SiteRoute('63003', 'site-daily-reports'),
    SiteRoute('63004', 'site-publications'),
    SiteRoute('63005', 'site-issues'),
    SiteRoute('63006', 'site-handovers'),
    SiteRoute('63007', 'site-customer-portal'),
    SiteRoute('63008', 'site-dashboard'),
  ];
}

List<GoRoute> buildSiteRoutes() => SiteRoutes.all
    .map(
      (route) => GoRoute(
        path: route.routePath,
        name: route.routeName,
        builder: (context, state) =>
            SiteScreen(menuCode: route.menuCode, routeName: route.routeName),
      ),
    )
    .toList();

List<GoRoute> buildSitePublicRoutes() => [
  GoRoute(
    path: '/site/customer',
    name: 'site-customer-login',
    builder: (context, state) => const SiteCustomerPortalPage(),
  ),
];
