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
  static const employeeSettings = '28001';
  static const systemSettings = '28002';
}

abstract final class TimeRouteNames {
  static const employeeSettings = 'timeEmployeeSettings';
  static const systemSettings = 'timeSystemSettings';
}

abstract final class TimeRoutePaths {
  static const employeeSettings = '/company/time-employee-settings';
  static const systemSettings = '/company/time-system-settings';
}

abstract final class TimeRoutes {
  static const employeeSettings = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.employeeSettings,
    screenType: 2,
    routeName: TimeRouteNames.employeeSettings,
    routePath: TimeRoutePaths.employeeSettings,
    isImplemented: false,
  );

  static const systemSettings = FeatureRouteContract(
    projectCode: TimeProject.code,
    menuCode: TimeMenuCodes.systemSettings,
    screenType: 2,
    routeName: TimeRouteNames.systemSettings,
    routePath: TimeRoutePaths.systemSettings,
    isImplemented: false,
  );

  static const all = <FeatureRouteContract>[employeeSettings, systemSettings];

  static Iterable<FeatureRouteContract> get implemented =>
      all.where((route) => route.isImplemented);
}
