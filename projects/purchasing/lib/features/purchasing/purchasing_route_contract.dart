import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class PurchasingProject {
  static const code = 'LAOO_PURCHASING';
}

abstract final class PurchasingMenuCodes {
  static const requests = '69002';
}

abstract final class PurchasingRouteNames {
  static const requests = 'purchasingRequests';
}

abstract final class PurchasingRoutePaths {
  static const requests = '/company/purchasing-requests';
}

abstract final class PurchasingRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: PurchasingProject.code,
      menuCode: PurchasingMenuCodes.requests,
      screenType: 4,
      routeName: PurchasingRouteNames.requests,
      routePath: PurchasingRoutePaths.requests,
    ),
  ];

  static Iterable<FeatureRouteContract> get implemented =>
      all.where((route) => route.isImplemented);
}
