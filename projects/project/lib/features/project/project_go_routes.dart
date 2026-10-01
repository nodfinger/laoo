import 'package:go_router/go_router.dart';
import 'project_page.dart';
import 'project_route_contract.dart';

List<GoRoute> buildProjectFeatureRoutes() => [
  _r(
    ProjectRoutePaths.settings,
    ProjectRouteNames.settings,
    ProjectMenuCodes.settings,
    'ตั้งค่าระบบบริหารโครงการ',
    ProjectPageMode.settings,
  ),
  _r(
    ProjectRoutePaths.budgetCategories,
    ProjectRouteNames.budgetCategories,
    ProjectMenuCodes.budgetCategories,
    'หมวดงบประมาณโครงการ',
    ProjectPageMode.categories,
  ),
  _r(
    ProjectRoutePaths.projects,
    ProjectRouteNames.projects,
    ProjectMenuCodes.projects,
    'โครงการ',
    ProjectPageMode.projects,
  ),
  _r(
    ProjectRoutePaths.myTasks,
    ProjectRouteNames.myTasks,
    ProjectMenuCodes.myTasks,
    'งานของฉัน',
    ProjectPageMode.myTasks,
  ),
  _r(
    ProjectRoutePaths.reports,
    ProjectRouteNames.reports,
    ProjectMenuCodes.reports,
    'รายงานโครงการ',
    ProjectPageMode.reports,
  ),
];
GoRoute _r(String p, String n, String m, String t, ProjectPageMode mode) =>
    GoRoute(
      path: p,
      name: n,
      builder: (_, __) =>
          ProjectPage(menuCode: m, fallbackTitle: t, mode: mode),
    );
