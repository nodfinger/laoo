import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo/app/router/app_router.dart';
import 'package:laoo_meeting/meeting_feature.dart';
import 'package:laoo_service/service_feature.dart';
import 'package:laoo_time/time_feature.dart';
import 'package:laoo_training/training_feature.dart';
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
    'Visitor settings route is routable while other catalog routes remain reserved',
    () {
      expect(VisitorRoutes.all, hasLength(23));
      expect(VisitorRoutes.implemented.map((route) => route.menuCode), [
        '36004',
      ]);
      for (final route in VisitorRoutes.all) {
        expect(route.projectCode, VisitorProject.code);
        if (route.menuCode == '36004') {
          expect(AppMenuRouteRegistry.byMenuCode(route.menuCode), isNotNull);
        } else {
          expect(AppMenuRouteRegistry.byMenuCode(route.menuCode), isNull);
        }
      }
    },
  );

  test('Time exposes only implemented routes to the Center host', () {
    final implemented = TimeRoutes.implemented.toList();

    expect(implemented, hasLength(TimeRoutes.all.length));
    expect(buildTimeFeatureRoutes(), hasLength(implemented.length));
    for (final route in implemented) {
      expect(AppMenuRouteRegistry.byMenuCode(route.menuCode), isNotNull);
    }
  });

  test('Training menu and internal routes are composed separately', () {
    final routes = buildTrainingFeatureRoutes();
    final names = routes.map((route) => route.name).toSet();
    final paths = routes.map((route) => route.path).toSet();
    final centerPaths = appRouter.configuration.routes
        .whereType<GoRoute>()
        .map((route) => route.path)
        .toSet();
    final menuRouteNames = TrainingRoutes.all
        .map((route) => route.routeName)
        .toSet();
    final menuRoutePaths = TrainingRoutes.all
        .map((route) => route.routePath)
        .toSet();

    expect(
      menuRouteNames,
      containsAll(<String>{
        TrainingRouteNames.types,
        TrainingRouteNames.instructors,
        TrainingRouteNames.testTemplates,
      }),
    );
    expect(menuRouteNames, isNot(contains(TrainingRouteNames.tests)));
    expect(
      menuRoutePaths,
      containsAll(<String>{
        TrainingRoutePaths.types,
        TrainingRoutePaths.instructors,
        TrainingRoutePaths.testTemplates,
      }),
    );
    expect(menuRoutePaths, isNot(contains(TrainingRoutePaths.tests)));
    expect(names, containsAll(menuRouteNames));
    expect(paths, containsAll(menuRoutePaths));
    expect(names, contains(TrainingRouteNames.tests));
    expect(paths, contains(TrainingRoutePaths.tests));
    expect(centerPaths, containsAll(paths));
    for (final route in TrainingRoutes.all) {
      expect(AppMenuRouteRegistry.byMenuCode(route.menuCode), isNotNull);
    }
  });
  test('Time leave request routes replace Root placeholders exactly once', () {
    final centerRoutes = appRouter.configuration.routes.whereType<GoRoute>();
    const leavePaths = <String>{
      TimeRoutePaths.leaveRequests,
      TimeRoutePaths.leaveApprovalInbox,
      TimeRoutePaths.myLeaveRequests,
    };

    for (final path in leavePaths) {
      expect(centerRoutes.where((route) => route.path == path), hasLength(1));
    }
  });
}
