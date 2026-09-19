export 'features/project/project_feature_host.dart';
export 'features/project/project_go_routes.dart';
export 'features/project/project_route_contract.dart';

import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class ProjectManagementProject {
  static const code = 'LAOO_PROJECT';
}

abstract final class ProjectMenuCodes {
  static const settings = '42001';
  static const budgetCategories = '42002';
  static const projects = '42003';
  static const myTasks = '42004';
  static const reports = '42005';
}

abstract final class ProjectRouteNames {
  static const settings = 'projectSettings';
  static const budgetCategories = 'projectBudgetCategories';
  static const projects = 'projects';
  static const myTasks = 'myProjectTasks';
  static const reports = 'projectReports';
}

abstract final class ProjectRoutePaths {
  static const settings = '/company/project-settings';
  static const budgetCategories = '/company/project-budget-categories';
  static const projects = '/company/projects';
  static const myTasks = '/company/my-project-tasks';
  static const reports = '/company/project-reports';
}

abstract final class ProjectRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: ProjectManagementProject.code,
      menuCode: ProjectMenuCodes.settings,
      screenType: 2,
      routeName: ProjectRouteNames.settings,
      routePath: ProjectRoutePaths.settings,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: ProjectManagementProject.code,
      menuCode: ProjectMenuCodes.budgetCategories,
      screenType: 1,
      routeName: ProjectRouteNames.budgetCategories,
      routePath: ProjectRoutePaths.budgetCategories,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: ProjectManagementProject.code,
      menuCode: ProjectMenuCodes.projects,
      screenType: 4,
      routeName: ProjectRouteNames.projects,
      routePath: ProjectRoutePaths.projects,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: ProjectManagementProject.code,
      menuCode: ProjectMenuCodes.myTasks,
      screenType: 2,
      routeName: ProjectRouteNames.myTasks,
      routePath: ProjectRoutePaths.myTasks,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: ProjectManagementProject.code,
      menuCode: ProjectMenuCodes.reports,
      screenType: 3,
      routeName: ProjectRouteNames.reports,
      routePath: ProjectRoutePaths.reports,
      isImplemented: false,
    ),
  ];

  static Iterable<FeatureRouteContract> get implemented =>
      all.where((route) => route.isImplemented);
}
