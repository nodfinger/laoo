export 'features/pos/pos_feature_host.dart';
export 'features/pos/pos_go_routes.dart';
export 'features/pos/pos_route_contract.dart';

import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class PosProject {
  static const code = 'LAOO_POS';
}

abstract final class PosMenuCodes {
  static const settings = '46001';
  static const outletsAndTerminals = '46002';
  static const outletItems = '46003';
  static const sales = '46004';
  static const cashShifts = '46005';
  static const returns = '46006';
  static const reports = '46007';
}

abstract final class PosRouteNames {
  static const settings = 'posSettings';
  static const outletsAndTerminals = 'posOutletsTerminals';
  static const outletItems = 'posOutletItems';
  static const sales = 'posSales';
  static const cashShifts = 'posCashShifts';
  static const returns = 'posReturns';
  static const reports = 'posReports';
}

abstract final class PosRoutePaths {
  static const settings = '/company/pos-settings';
  static const outletsAndTerminals = '/company/pos-outlets-terminals';
  static const outletItems = '/company/pos-outlet-items';
  static const sales = '/company/pos-sales';
  static const cashShifts = '/company/pos-cash-shifts';
  static const returns = '/company/pos-returns';
  static const reports = '/company/pos-reports';
}

abstract final class PosRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: PosProject.code,
      menuCode: PosMenuCodes.settings,
      screenType: 2,
      routeName: PosRouteNames.settings,
      routePath: PosRoutePaths.settings,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: PosProject.code,
      menuCode: PosMenuCodes.outletsAndTerminals,
      screenType: 1,
      routeName: PosRouteNames.outletsAndTerminals,
      routePath: PosRoutePaths.outletsAndTerminals,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: PosProject.code,
      menuCode: PosMenuCodes.outletItems,
      screenType: 1,
      routeName: PosRouteNames.outletItems,
      routePath: PosRoutePaths.outletItems,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: PosProject.code,
      menuCode: PosMenuCodes.sales,
      screenType: 4,
      routeName: PosRouteNames.sales,
      routePath: PosRoutePaths.sales,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: PosProject.code,
      menuCode: PosMenuCodes.cashShifts,
      screenType: 4,
      routeName: PosRouteNames.cashShifts,
      routePath: PosRoutePaths.cashShifts,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: PosProject.code,
      menuCode: PosMenuCodes.returns,
      screenType: 4,
      routeName: PosRouteNames.returns,
      routePath: PosRoutePaths.returns,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: PosProject.code,
      menuCode: PosMenuCodes.reports,
      screenType: 3,
      routeName: PosRouteNames.reports,
      routePath: PosRoutePaths.reports,
      isImplemented: false,
    ),
  ];

  static Iterable<FeatureRouteContract> get implemented =>
      all.where((route) => route.isImplemented);
}
