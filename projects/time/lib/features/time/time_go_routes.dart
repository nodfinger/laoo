import 'package:go_router/go_router.dart';

import 'pages/time_preview_page.dart';
import 'time_route_contract.dart';

List<GoRoute> buildTimeFeatureRoutes() => [
  GoRoute(
    path: TimeRoutes.employeeSettings.routePath,
    name: TimeRoutes.employeeSettings.effectiveGoRouteName,
    builder: (context, state) =>
        TimeEmployeeSettingsPreviewPage(route: TimeRoutes.employeeSettings),
  ),
  GoRoute(
    path: TimeRoutes.systemSettings.routePath,
    name: TimeRoutes.systemSettings.effectiveGoRouteName,
    builder: (context, state) =>
        TimeSystemSettingsPreviewPage(route: TimeRoutes.systemSettings),
  ),
];
