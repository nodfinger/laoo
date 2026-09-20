import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class FiveSProject {
  static const code = 'LAOO_5S';
}

abstract final class FiveSMenuCodes {
  static const settings = '39010';
  static const inspectionAreas = '39001';
  static const templates = '39002';
  static const inspectionTeams = '39003';
  static const inspectionPlans = '39004';
  static const inspections = '39005';
  static const inspectionConfirmations = '39006';
  static const findings = '39007';
  static const inspectionHistory = '39008';
  static const reports = '39009';
}

abstract final class FiveSRouteNames {
  static const settings = 'fiveSSettings';
  static const inspectionAreas = 'fiveSInspectionAreas';
  static const templates = 'fiveSTemplates';
  static const inspectionTeams = 'fiveSInspectionTeams';
  static const inspectionPlans = 'fiveSInspectionPlans';
  static const inspections = 'fiveSInspections';
  static const inspectionConfirmations = 'fiveSInspectionConfirmations';
  static const findings = 'fiveSFindings';
  static const inspectionHistory = 'fiveSInspectionHistory';
  static const reports = 'fiveSReports';
}

abstract final class FiveSRoutePaths {
  static const settings = '/company/five-s/settings';
  static const inspectionAreas = '/company/five-s/inspection-areas';
  static const templates = '/company/five-s/templates';
  static const inspectionTeams = '/company/five-s/inspection-teams';
  static const inspectionPlans = '/company/five-s/inspection-plans';
  static const inspections = '/company/five-s/inspections';
  static const inspectionConfirmations =
      '/company/five-s/inspection-confirmations';
  static const findings = '/company/five-s/findings';
  static const inspectionHistory = '/company/five-s/inspection-history';
  static const reports = '/company/five-s/reports';
}

abstract final class FiveSRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: FiveSProject.code,
      menuCode: FiveSMenuCodes.settings,
      screenType: 2,
      routeName: FiveSRouteNames.settings,
      routePath: FiveSRoutePaths.settings,
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: FiveSProject.code,
      menuCode: FiveSMenuCodes.inspectionAreas,
      screenType: 1,
      routeName: FiveSRouteNames.inspectionAreas,
      routePath: FiveSRoutePaths.inspectionAreas,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: FiveSProject.code,
      menuCode: FiveSMenuCodes.templates,
      screenType: 1,
      routeName: FiveSRouteNames.templates,
      routePath: FiveSRoutePaths.templates,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: FiveSProject.code,
      menuCode: FiveSMenuCodes.inspectionTeams,
      screenType: 1,
      routeName: FiveSRouteNames.inspectionTeams,
      routePath: FiveSRoutePaths.inspectionTeams,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: FiveSProject.code,
      menuCode: FiveSMenuCodes.inspectionPlans,
      screenType: 1,
      routeName: FiveSRouteNames.inspectionPlans,
      routePath: FiveSRoutePaths.inspectionPlans,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: FiveSProject.code,
      menuCode: FiveSMenuCodes.inspections,
      screenType: 4,
      routeName: FiveSRouteNames.inspections,
      routePath: FiveSRoutePaths.inspections,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: FiveSProject.code,
      menuCode: FiveSMenuCodes.inspectionConfirmations,
      screenType: 2,
      routeName: FiveSRouteNames.inspectionConfirmations,
      routePath: FiveSRoutePaths.inspectionConfirmations,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: FiveSProject.code,
      menuCode: FiveSMenuCodes.findings,
      screenType: 2,
      routeName: FiveSRouteNames.findings,
      routePath: FiveSRoutePaths.findings,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: FiveSProject.code,
      menuCode: FiveSMenuCodes.inspectionHistory,
      screenType: 3,
      routeName: FiveSRouteNames.inspectionHistory,
      routePath: FiveSRoutePaths.inspectionHistory,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: FiveSProject.code,
      menuCode: FiveSMenuCodes.reports,
      screenType: 3,
      routeName: FiveSRouteNames.reports,
      routePath: FiveSRoutePaths.reports,
      isImplemented: false,
    ),
  ];

  static Iterable<FeatureRouteContract> get implemented =>
      all.where((route) => route.isImplemented);
}
