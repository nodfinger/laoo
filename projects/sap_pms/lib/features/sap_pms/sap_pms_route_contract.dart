import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class SapPmsProject {
  static const code = 'LAOO_MY';
}

abstract final class SapPmsMenuCodes {
  static const sapPms = '65002';
}

abstract final class SapPmsRouteNames {
  static const sapPms = 'mySystemSapPms';
}

abstract final class SapPmsRoutePaths {
  static const sapPms = '/company/my-system/sap-pms';
}

abstract final class SapPmsRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: SapPmsProject.code,
      menuCode: SapPmsMenuCodes.sapPms,
      screenType: 3,
      routeName: SapPmsRouteNames.sapPms,
      routePath: SapPmsRoutePaths.sapPms,
      isImplemented: false,
    ),
  ];
}
