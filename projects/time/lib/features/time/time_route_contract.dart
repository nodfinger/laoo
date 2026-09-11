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
  static const shiftTemplates = '27001';
  static const scheduleGroups = '27002';
  static const rotationPatterns = '27003';
  static const employeeSchedules = '27004';
  static const employeeSettings = '28001';
  static const systemSettings = '28002';
}

abstract final class TimeRouteNames {
  static const shiftTemplates = 'timeShiftTemplates';
  static const scheduleGroups = 'timeScheduleGroups';
  static const rotationPatterns = 'timeRotationPatterns';
  static const employeeSchedules = 'timeEmployeeSchedules';
  static const employeeSettings = 'timeEmployeeSettings';
  static const systemSettings = 'timeSystemSettings';
}

abstract final class TimeRoutePaths {
  static const shiftTemplates = '/company/time-shift-templates';
  static const scheduleGroups = '/company/time-schedule-groups';
  static const rotationPatterns = '/company/time-rotation-patterns';
  static const employeeSchedules = '/company/time-employee-schedules';
  static const employeeSettings = '/company/time-employee-settings';
  static const systemSettings = '/company/time-system-settings';
}

abstract final class TimeRoutes {
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

  static const all = <FeatureRouteContract>[
    shiftTemplates,
    scheduleGroups,
    rotationPatterns,
    employeeSchedules,
    employeeSettings,
    systemSettings,
  ];

  static Iterable<FeatureRouteContract> get implemented =>
      all.where((route) => route.isImplemented);
}
