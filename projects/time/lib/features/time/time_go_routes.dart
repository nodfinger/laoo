import 'package:go_router/go_router.dart';

import '../employee_settings/employee_time_settings_page.dart';
import '../system_settings/time_system_settings_page.dart';
import '../shift_templates/shift_template_page.dart';
import '../schedule_groups/schedule_group_page.dart';
import '../rotation_patterns/rotation_pattern_page.dart';
import '../employee_schedules/employee_schedule_page.dart';
import 'time_route_contract.dart';
import '../time_corrections/time_correction_page.dart';
import '../time_reasons/time_reason_page.dart';
import '../attendance_periods/attendance_period_pages.dart';
import '../attendance_events/attendance_events_page.dart';
import '../attendance_results/attendance_results_page.dart';
import '../attendance_summary/attendance_summary_page.dart';
import '../holiday_calendars/holiday_calendar_page.dart';
import '../holiday_calendars/holiday_date_page.dart';
import '../holiday_calendars/branch_holiday_calendar_page.dart';
import '../holiday_calendars/branch_holiday_exception_page.dart';
import '../my_attendance_history/my_attendance_history_page.dart';

List<GoRoute> buildTimeFeatureRoutes() => <GoRoute>[
  GoRoute(
    name: TimeRouteNames.myAttendanceHistory,
    path: TimeRoutePaths.myAttendanceHistory,
    builder: (context, state) => const MyAttendanceHistoryPage(),
  ),
  GoRoute(
    name: TimeRouteNames.branchHolidayExceptions,
    path: TimeRoutePaths.branchHolidayExceptions,
    builder: (context, state) => const BranchHolidayExceptionPage(),
  ),
  GoRoute(
    name: TimeRouteNames.branchHolidayCalendars,
    path: TimeRoutePaths.branchHolidayCalendars,
    builder: (context, state) => const BranchHolidayCalendarPage(),
  ),
  GoRoute(
    name: TimeRouteNames.holidayDates,
    path: TimeRoutePaths.holidayDates,
    builder: (context, state) => const HolidayDatePage(),
  ),
  GoRoute(
    name: TimeRouteNames.holidayCalendars,
    path: TimeRoutePaths.holidayCalendars,
    builder: (context, state) => const HolidayCalendarPage(),
  ),
  GoRoute(
    name: TimeRouteNames.attendancePeriodSchemes,
    path: TimeRoutePaths.attendancePeriodSchemes,
    builder: (context, state) => const AttendancePeriodSchemesPage(),
  ),
  GoRoute(
    name: TimeRouteNames.attendancePeriodAssignments,
    path: TimeRoutePaths.attendancePeriodAssignments,
    builder: (context, state) => const AttendancePeriodAssignmentsPage(),
  ),
  GoRoute(
    name: TimeRouteNames.attendancePeriods,
    path: TimeRoutePaths.attendancePeriods,
    builder: (context, state) => const AttendancePeriodsPage(),
  ),
  GoRoute(
    name: TimeRouteNames.attendanceEvents,
    path: TimeRoutePaths.attendanceEvents,
    builder: (context, state) => const AttendanceEventsPage(),
  ),
  GoRoute(
    name: TimeRouteNames.attendanceResults,
    path: TimeRoutePaths.attendanceResults,
    builder: (context, state) => const AttendanceResultsPage(),
  ),
  GoRoute(
    name: TimeRouteNames.attendanceSummaryReport,
    path: TimeRoutePaths.attendanceSummaryReport,
    builder: (context, state) => const AttendanceSummaryPage(),
  ),
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
  GoRoute(
    name: TimeRouteNames.timeCorrectionProxy,
    path: TimeRoutePaths.timeCorrectionProxy,
    builder: (context, state) => const TimeCorrectionPage(
      menuCode: TimeMenuCodes.timeCorrectionProxy,
      mode: 'proxy',
    ),
  ),
  GoRoute(
    name: TimeRouteNames.timeApprovalInbox,
    path: TimeRoutePaths.timeApprovalInbox,
    builder: (context, state) => const TimeCorrectionPage(
      menuCode: TimeMenuCodes.timeApprovalInbox,
      mode: 'approval',
    ),
  ),
  GoRoute(
    name: TimeRouteNames.onBehalfReasons,
    path: TimeRoutePaths.onBehalfReasons,
    builder: (context, state) => const TimeReasonPage(
      menuCode: TimeMenuCodes.onBehalfReasons,
      apiPath: '/api/time/on-behalf-reasons',
    ),
  ),
  GoRoute(
    name: TimeRouteNames.adjustmentReasons,
    path: TimeRoutePaths.adjustmentReasons,
    builder: (context, state) => const TimeReasonPage(
      menuCode: TimeMenuCodes.adjustmentReasons,
      apiPath: '/api/time/adjustment-reasons',
    ),
  ),
  GoRoute(
    name: TimeRouteNames.myTimeCorrections,
    path: TimeRoutePaths.myTimeCorrections,
    builder: (context, state) => const TimeCorrectionPage(
      menuCode: TimeMenuCodes.myTimeCorrections,
      mode: 'self',
    ),
  ),
];
