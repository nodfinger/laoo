import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class PatrolProject {
  static const code = 'LAOO_PATROL';
}

abstract final class PatrolMenuCodes {
  static const settings = '56001',
      checkpoints = '56002',
      devices = '56003',
      credentials = '56004',
      checklists = '56005',
      routes = '56006',
      schedules = '56007',
      runs = '56008',
      monitor = '56009',
      incidents = '56010',
      audit = '56011',
      dashboard = '56012';
}

abstract final class PatrolRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: PatrolProject.code,
      menuCode: '56001',
      screenType: 2,
      routeName: 'patrol-settings',
      routePath: '/company/patrol-settings',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: PatrolProject.code,
      menuCode: '56002',
      screenType: 1,
      routeName: 'patrol-checkpoints',
      routePath: '/company/patrol-checkpoints',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: PatrolProject.code,
      menuCode: '56003',
      screenType: 1,
      routeName: 'patrol-devices',
      routePath: '/company/patrol-devices',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: PatrolProject.code,
      menuCode: '56004',
      screenType: 1,
      routeName: 'patrol-credentials',
      routePath: '/company/patrol-credentials',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: PatrolProject.code,
      menuCode: '56005',
      screenType: 1,
      routeName: 'patrol-checklists',
      routePath: '/company/patrol-checklists',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: PatrolProject.code,
      menuCode: '56006',
      screenType: 1,
      routeName: 'patrol-routes',
      routePath: '/company/patrol-routes',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: PatrolProject.code,
      menuCode: '56007',
      screenType: 4,
      routeName: 'patrol-schedules',
      routePath: '/company/patrol-schedules',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: PatrolProject.code,
      menuCode: '56008',
      screenType: 4,
      routeName: 'patrol-runs',
      routePath: '/company/patrol-runs',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: PatrolProject.code,
      menuCode: '56009',
      screenType: 3,
      routeName: 'patrol-monitor',
      routePath: '/company/patrol-monitor',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: PatrolProject.code,
      menuCode: '56010',
      screenType: 3,
      routeName: 'patrol-incidents',
      routePath: '/company/patrol-incidents',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: PatrolProject.code,
      menuCode: '56011',
      screenType: 3,
      routeName: 'patrol-audit',
      routePath: '/company/patrol-audit',
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: PatrolProject.code,
      menuCode: '56012',
      screenType: 3,
      routeName: 'patrol-dashboard',
      routePath: '/company/patrol-dashboard',
      isImplemented: true,
    ),
  ];

  static List<FeatureRouteContract> get implemented =>
      all.where((route) => route.isImplemented).toList(growable: false);
}
