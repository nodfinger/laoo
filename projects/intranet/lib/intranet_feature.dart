export 'features/intranet/intranet_feature_host.dart';
export 'features/intranet/intranet_go_routes.dart';
export 'features/intranet/intranet_route_contract.dart';

import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class IntranetProject {
  static const code = 'LAOO_INTRANET';
}

abstract final class IntranetMenuCodes {
  static const settings = '43001';
  static const content = '43002';
  static const approvalInbox = '43003';
  static const myIntranet = '43004';
  static const reports = '43005';
}

abstract final class IntranetRouteNames {
  static const settings = 'intranetSettings';
  static const content = 'intranetContent';
  static const approvalInbox = 'intranetApprovalInbox';
  static const myIntranet = 'myIntranet';
  static const reports = 'intranetReports';
}

abstract final class IntranetRoutePaths {
  static const settings = '/company/intranet-settings';
  static const content = '/company/intranet-content';
  static const approvalInbox = '/company/intranet-approvals';
  static const myIntranet = '/company/my-intranet';
  static const reports = '/company/intranet-reports';
}

abstract final class IntranetRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: IntranetProject.code,
      menuCode: IntranetMenuCodes.settings,
      screenType: 2,
      routeName: IntranetRouteNames.settings,
      routePath: IntranetRoutePaths.settings,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: IntranetProject.code,
      menuCode: IntranetMenuCodes.content,
      screenType: 4,
      routeName: IntranetRouteNames.content,
      routePath: IntranetRoutePaths.content,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: IntranetProject.code,
      menuCode: IntranetMenuCodes.approvalInbox,
      screenType: 3,
      routeName: IntranetRouteNames.approvalInbox,
      routePath: IntranetRoutePaths.approvalInbox,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: IntranetProject.code,
      menuCode: IntranetMenuCodes.myIntranet,
      screenType: 3,
      routeName: IntranetRouteNames.myIntranet,
      routePath: IntranetRoutePaths.myIntranet,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: IntranetProject.code,
      menuCode: IntranetMenuCodes.reports,
      screenType: 3,
      routeName: IntranetRouteNames.reports,
      routePath: IntranetRoutePaths.reports,
      isImplemented: false,
    ),
  ];

  static Iterable<FeatureRouteContract> get implemented =>
      all.where((route) => route.isImplemented);
}
