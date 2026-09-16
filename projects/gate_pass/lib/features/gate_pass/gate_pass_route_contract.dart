import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class GatePassProject {
  static const code = 'LAOO_GATE_PASS';
}

abstract final class GatePassMenuCodes {
  static const settings = '38001';
  static const purposes = '38002';
  static const requests = '38003';
  static const approvalInbox = '38004';
  static const exitCheck = '38005';
  static const returnTracking = '38006';
  static const myGatePasses = '38007';
  static const reports = '38008';
}

abstract final class GatePassRouteNames {
  static const settings = 'gatePassSettings';
  static const purposes = 'gatePassPurposes';
  static const requests = 'gatePassRequests';
  static const approvalInbox = 'gatePassApprovalInbox';
  static const exitCheck = 'gatePassExitCheck';
  static const returnTracking = 'gatePassReturnTracking';
  static const myGatePasses = 'myGatePasses';
  static const reports = 'gatePassReports';
}

abstract final class GatePassRoutePaths {
  static const settings = '/company/gate-pass-settings';
  static const purposes = '/company/gate-pass-purposes';
  static const requests = '/company/gate-passes';
  static const approvalInbox = '/company/gate-pass-approvals';
  static const exitCheck = '/company/gate-pass-exit-check';
  static const returnTracking = '/company/gate-pass-returns';
  static const myGatePasses = '/company/my-gate-passes';
  static const reports = '/company/gate-pass-reports';
}

abstract final class GatePassRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: GatePassProject.code,
      menuCode: GatePassMenuCodes.settings,
      screenType: 2,
      routeName: GatePassRouteNames.settings,
      routePath: GatePassRoutePaths.settings,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: GatePassProject.code,
      menuCode: GatePassMenuCodes.purposes,
      screenType: 1,
      routeName: GatePassRouteNames.purposes,
      routePath: GatePassRoutePaths.purposes,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: GatePassProject.code,
      menuCode: GatePassMenuCodes.requests,
      screenType: 4,
      routeName: GatePassRouteNames.requests,
      routePath: GatePassRoutePaths.requests,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: GatePassProject.code,
      menuCode: GatePassMenuCodes.approvalInbox,
      screenType: 3,
      routeName: GatePassRouteNames.approvalInbox,
      routePath: GatePassRoutePaths.approvalInbox,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: GatePassProject.code,
      menuCode: GatePassMenuCodes.exitCheck,
      screenType: 2,
      routeName: GatePassRouteNames.exitCheck,
      routePath: GatePassRoutePaths.exitCheck,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: GatePassProject.code,
      menuCode: GatePassMenuCodes.returnTracking,
      screenType: 2,
      routeName: GatePassRouteNames.returnTracking,
      routePath: GatePassRoutePaths.returnTracking,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: GatePassProject.code,
      menuCode: GatePassMenuCodes.myGatePasses,
      screenType: 4,
      routeName: GatePassRouteNames.myGatePasses,
      routePath: GatePassRoutePaths.myGatePasses,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: GatePassProject.code,
      menuCode: GatePassMenuCodes.reports,
      screenType: 3,
      routeName: GatePassRouteNames.reports,
      routePath: GatePassRoutePaths.reports,
      isImplemented: false,
    ),
  ];

  static Iterable<FeatureRouteContract> get implemented =>
      all.where((route) => route.isImplemented);
}
