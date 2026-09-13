import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class TimeProject {
  static const code = 'LAOO_TIME';
}

abstract final class TimeMenuGroups {
  static const attendance = '25';
  static const requests = '26';
  static const schedules = '27';
  static const setup = '28';
  static const periodsAndReports = '29';
  static const selfService = '30';
}

abstract final class TimeMenuCodes {
  static const attendanceEvents = '25001';
  static const attendanceResults = '25002';
  static const shiftTemplates = '27001';
  static const scheduleGroups = '27002';
  static const rotationPatterns = '27003';
  static const employeeSchedules = '27004';
  static const employeeSettings = '28001';
  static const systemSettings = '28002';
  static const timeCorrectionProxy = '26001';
  static const timeApprovalInbox = '26002';
  static const onBehalfReasons = '28003';
  static const adjustmentReasons = '28004';
  static const myTimeCorrections = '30001';
  static const attendancePeriodSchemes = '29001';
  static const attendancePeriodAssignments = '29002';
  static const attendancePeriods = '29003';
}

abstract final class TimeRouteNames {
  static const attendanceEvents = 'timeAttendanceEvents';
  static const attendanceResults = 'timeAttendanceResults';
  static const shiftTemplates = 'timeShiftTemplates';
  static const scheduleGroups = 'timeScheduleGroups';
  static const rotationPatterns = 'timeRotationPatterns';
  static const employeeSchedules = 'timeEmployeeSchedules';
  static const employeeSettings = 'timeEmployeeSettings';
  static const systemSettings = 'timeSystemSettings';
  static const timeCorrectionProxy = 'timeCorrectionProxy';
  static const timeApprovalInbox = 'timeApprovalInbox';
  static const onBehalfReasons = 'timeOnBehalfReasons';
  static const adjustmentReasons = 'timeAdjustmentReasons';
  static const myTimeCorrections = 'myTimeCorrections';
  static const attendancePeriodSchemes = 'timeAttendancePeriodSchemes';
  static const attendancePeriodAssignments = 'timeAttendancePeriodAssignments';
  static const attendancePeriods = 'timeAttendancePeriods';
}

abstract final class TimeRoutePaths {
  static const attendanceEvents = '/company/time-attendance-events';
  static const attendanceResults = '/company/time-attendance-results';
  static const shiftTemplates = '/company/time-shift-templates';
  static const scheduleGroups = '/company/time-schedule-groups';
  static const rotationPatterns = '/company/time-rotation-patterns';
  static const employeeSchedules = '/company/time-employee-schedules';
  static const employeeSettings = '/company/time-employee-settings';
  static const systemSettings = '/company/time-system-settings';
  static const timeCorrectionProxy = '/company/time-corrections';
  static const timeApprovalInbox = '/company/time-approval-inbox';
  static const onBehalfReasons = '/company/time-on-behalf-reasons';
  static const adjustmentReasons = '/company/time-adjustment-reasons';
  static const myTimeCorrections = '/company/my-time-corrections';
  static const attendancePeriodSchemes =
      '/company/time-attendance-period-schemes';
  static const attendancePeriodAssignments =
      '/company/time-attendance-period-assignments';
  static const attendancePeriods = '/company/time-attendance-periods';
}

abstract final class TimeRoutes {
  static const attendanceEvents = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.attendanceEvents,
    screenType: 3,
    routeName: TimeRouteNames.attendanceEvents,
    routePath: TimeRoutePaths.attendanceEvents,
    isImplemented: true,
  );

  static const attendanceResults = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.attendanceResults,
    screenType: 3,
    routeName: TimeRouteNames.attendanceResults,
    routePath: TimeRoutePaths.attendanceResults,
    isImplemented: true,
  );

  static const shiftTemplates = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.shiftTemplates,
    screenType: 1,
    routeName: TimeRouteNames.shiftTemplates,
    routePath: TimeRoutePaths.shiftTemplates,
    isImplemented: true,
  );

  static const scheduleGroups = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.scheduleGroups,
    screenType: 1,
    routeName: TimeRouteNames.scheduleGroups,
    routePath: TimeRoutePaths.scheduleGroups,
    isImplemented: true,
  );

  static const rotationPatterns = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.rotationPatterns,
    screenType: 1,
    routeName: TimeRouteNames.rotationPatterns,
    routePath: TimeRoutePaths.rotationPatterns,
    isImplemented: true,
  );

  static const employeeSchedules = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.employeeSchedules,
    screenType: 1,
    routeName: TimeRouteNames.employeeSchedules,
    routePath: TimeRoutePaths.employeeSchedules,
    isImplemented: true,
  );
  static const employeeSettings = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.employeeSettings,
    screenType: 2,
    routeName: TimeRouteNames.employeeSettings,
    routePath: TimeRoutePaths.employeeSettings,
    isImplemented: true,
  );

  static const systemSettings = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.systemSettings,
    screenType: 2,
    routeName: TimeRouteNames.systemSettings,
    routePath: TimeRoutePaths.systemSettings,
    isImplemented: true,
  );

  static const timeCorrectionProxy = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.timeCorrectionProxy,
    screenType: 4,
    routeName: TimeRouteNames.timeCorrectionProxy,
    routePath: TimeRoutePaths.timeCorrectionProxy,
    isImplemented: true,
  );
  static const timeApprovalInbox = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.timeApprovalInbox,
    screenType: 3,
    routeName: TimeRouteNames.timeApprovalInbox,
    routePath: TimeRoutePaths.timeApprovalInbox,
    isImplemented: true,
  );
  static const onBehalfReasons = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.onBehalfReasons,
    screenType: 1,
    routeName: TimeRouteNames.onBehalfReasons,
    routePath: TimeRoutePaths.onBehalfReasons,
    isImplemented: true,
  );
  static const adjustmentReasons = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.adjustmentReasons,
    screenType: 1,
    routeName: TimeRouteNames.adjustmentReasons,
    routePath: TimeRoutePaths.adjustmentReasons,
    isImplemented: true,
  );
  static const myTimeCorrections = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.myTimeCorrections,
    screenType: 4,
    routeName: TimeRouteNames.myTimeCorrections,
    routePath: TimeRoutePaths.myTimeCorrections,
    isImplemented: true,
  );
  static const attendancePeriodSchemes = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.attendancePeriodSchemes,
    screenType: 1,
    routeName: TimeRouteNames.attendancePeriodSchemes,
    routePath: TimeRoutePaths.attendancePeriodSchemes,
    isImplemented: true,
  );
  static const attendancePeriodAssignments = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.attendancePeriodAssignments,
    screenType: 4,
    routeName: TimeRouteNames.attendancePeriodAssignments,
    routePath: TimeRoutePaths.attendancePeriodAssignments,
    isImplemented: true,
  );
  static const attendancePeriods = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.attendancePeriods,
    screenType: 3,
    routeName: TimeRouteNames.attendancePeriods,
    routePath: TimeRoutePaths.attendancePeriods,
    isImplemented: true,
  );

  static const all = <FeatureRouteContract>[
    attendanceEvents,
    attendanceResults,
    shiftTemplates,
    scheduleGroups,
    rotationPatterns,
    employeeSchedules,
    employeeSettings,
    systemSettings,
    timeCorrectionProxy,
    timeApprovalInbox,
    onBehalfReasons,
    adjustmentReasons,
    myTimeCorrections,
    attendancePeriodSchemes,
    attendancePeriodAssignments,
    attendancePeriods,
  ];

  static Iterable<FeatureRouteContract> get implemented =>
      all.where((route) => route.isImplemented);
}
