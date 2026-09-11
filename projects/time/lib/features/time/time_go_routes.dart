import 'package:go_router/go_router.dart';

import '../employee_settings/employee_time_settings_page.dart';
import 'time_route_contract.dart';

List<GoRoute> buildTimeFeatureRoutes() => <GoRoute>[
  GoRoute(
    name: TimeRouteNames.employeeSettings,
    path: TimeRoutePaths.employeeSettings,
    builder: (context, state) => const EmployeeTimeSettingsPage(),
  ),
];
