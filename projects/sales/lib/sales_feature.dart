export 'features/sales/sales_feature_host.dart';
export 'features/sales/sales_go_routes.dart';
export 'features/sales/sales_route_contract.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class SalesProject {
  static const code = 'LAOO_SALES';
}

abstract final class SalesMenuCodes {
  static const settings = '45001',
      pipelineStages = '45002',
      leads = '45003',
      opportunities = '45004',
      activities = '45005',
      myTasks = '45006',
      reports = '45007';
}

abstract final class SalesRouteNames {
  static const settings = 'salesSettings',
      pipelineStages = 'salesPipelineStages',
      leads = 'salesLeads',
      opportunities = 'salesOpportunities',
      activities = 'salesActivities',
      myTasks = 'mySalesTasks',
      reports = 'salesReports';
}

abstract final class SalesRoutePaths {
  static const settings = '/company/sales-settings',
      pipelineStages = '/company/sales-pipeline-stages',
      leads = '/company/sales-leads',
      opportunities = '/company/sales-opportunities',
      activities = '/company/sales-activities',
      myTasks = '/company/my-sales-tasks',
      reports = '/company/sales-reports';
}

abstract final class SalesRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: SalesProject.code,
      menuCode: SalesMenuCodes.settings,
      screenType: 2,
      routeName: SalesRouteNames.settings,
      routePath: SalesRoutePaths.settings,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: SalesProject.code,
      menuCode: SalesMenuCodes.pipelineStages,
      screenType: 1,
      routeName: SalesRouteNames.pipelineStages,
      routePath: SalesRoutePaths.pipelineStages,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: SalesProject.code,
      menuCode: SalesMenuCodes.leads,
      screenType: 4,
      routeName: SalesRouteNames.leads,
      routePath: SalesRoutePaths.leads,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: SalesProject.code,
      menuCode: SalesMenuCodes.opportunities,
      screenType: 4,
      routeName: SalesRouteNames.opportunities,
      routePath: SalesRoutePaths.opportunities,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: SalesProject.code,
      menuCode: SalesMenuCodes.activities,
      screenType: 4,
      routeName: SalesRouteNames.activities,
      routePath: SalesRoutePaths.activities,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: SalesProject.code,
      menuCode: SalesMenuCodes.myTasks,
      screenType: 2,
      routeName: SalesRouteNames.myTasks,
      routePath: SalesRoutePaths.myTasks,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: SalesProject.code,
      menuCode: SalesMenuCodes.reports,
      screenType: 3,
      routeName: SalesRouteNames.reports,
      routePath: SalesRoutePaths.reports,
      isImplemented: false,
    ),
  ];
  static Iterable<FeatureRouteContract> get implemented =>
      all.where((route) => route.isImplemented);
}
