import 'package:go_router/go_router.dart';

import '../employee_settings/employee_time_settings_page.dart';
import '../system_settings/time_system_settings_page.dart';
import '../shift_templates/shift_template_page.dart';
import '../schedule_groups/schedule_group_page.dart';
import '../rotation_patterns/rotation_pattern_page.dart';
import '../employee_schedules/employee_schedule_page.dart';
import 'time_route_contract.dart';

List<GoRoute> buildTimeFeatureRoutes() => <GoRoute>[
  GoRoute(
    name: TimeRouteNames.shiftTemplates,
    path: TimeRoutePaths.shiftTemplates,
    builder: (context, state) => const ShiftTemplatePage(),
  ),
  GoRoute(
    name: TimeRouteNames.employeeSchedules,
    path: TimeRoutePaths.employeeSchedules,
    builder: (context, state) => const EmployeeSchedulePage(),
  ),
  GoRoute(
    name: TimeRouteNames.rotationPatterns,
    path: TimeRoutePaths.rotationPatterns,
    builder: (context, state) => const RotationPatternPage(),
  ),
  GoRoute(
    name: TimeRouteNames.scheduleGroups,
    path: TimeRoutePaths.scheduleGroups,
    builder: (context, state) => const ScheduleGroupPage(),
  ),
  GoRoute(
    name: TimeRouteNames.employeeSettings,
    path: TimeRoutePaths.employeeSettings,
    builder: (context, state) => const EmployeeTimeSettingsPage(),
  ),
  GoRoute(
    name: TimeRouteNames.systemSettings,
    path: TimeRoutePaths.systemSettings,
    builder: (context, state) => const TimeSystemSettingsPage(),
  ),
];
