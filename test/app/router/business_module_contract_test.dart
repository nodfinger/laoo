import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo/app/router/app_router.dart';
import 'package:laoo_meeting/meeting_feature.dart';
import 'package:laoo_service/service_feature.dart';
import 'package:laoo_time/time_feature.dart';
import 'package:laoo_visitor/visitor_feature.dart';

void main() {
  test('Center composes Service and Meeting routes without duplicates', () {
    final businessRoutes = [
      ...ServiceRoutes.all.map(
        (route) => (
          menuCode: route.menuCode,
          routeName: route.effectiveGoRouteName,
          routePath: route.routePath,
        ),
      ),
      ...MeetingRoutes.all.map(
        (route) => (
          menuCode: route.menuCode,
          routeName: route.name,
          routePath: route.path,
        ),
      ),
    ];
    final menuCodes = businessRoutes.map((route) => route.menuCode).toList();
    final routeNames = businessRoutes.map((route) => route.routeName).toList();
    final routePaths = businessRoutes.map((route) => route.routePath).toList();

    expect(menuCodes.toSet(), hasLength(menuCodes.length));
    expect(routeNames.toSet(), hasLength(routeNames.length));
    expect(routePaths.toSet(), hasLength(routePaths.length));

    final centerRoutes = appRouter.configuration.routes.whereType<GoRoute>();
    final centerPaths = centerRoutes.map((route) => route.path).toSet();
    expect(centerPaths, containsAll(routePaths));

    for (final code in menuCodes) {
      expect(AppMenuRouteRegistry.byMenuCode(code), isNotNull);
    }
  });

  test('Serial registry is owned by the Core project', () {
    final route = ServiceRoutes.byMenuCode('08006');

    expect(route, isNotNull);
    expect(route.projectCode, 'LAOO');
    expect(route.screenType, 1);
  });

  test(
    'Visitor catalog is reserved but not routable before implementation',
    () {
      expect(VisitorRoutes.all, hasLength(22));
      expect(VisitorRoutes.implemented, isEmpty);
      for (final route in VisitorRoutes.all) {
        expect(route.projectCode, VisitorProject.code);
        expect(AppMenuRouteRegistry.byMenuCode(route.menuCode), isNull);
      }
    },
  );

  test('Time preview settings are routable after activation', () {
    expect(TimeRoutes.all, hasLength(2));
    expect(TimeRoutes.implemented, hasLength(2));
    for (final route in TimeRoutes.all) {
      expect(route.projectCode, TimeProject.code);
      expect(AppMenuRouteRegistry.byMenuCode(route.menuCode), isNotNull);
    }
  });
}
