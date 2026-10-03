final class SchoolMenuCodes {
  static const settings = '52001',
      levels = '52002',
      rounds = '52003',
      holidays = '52004',
      academics = '52005',
      students = '52006',
      guardians = '52007',
      attendance = '52008',
      rollCall = '52009',
      news = '52010',
      dailyReport = '52011',
      periodReport = '52012',
      dashboard = '52013',
      guardianPortal = '52014';
}

final class SchoolRouteSpec {
  const SchoolRouteSpec(this.menuCode, this.routeName, this.routePath);
  final String menuCode;
  final String routeName;
  final String routePath;
}

final class SchoolRoutes {
  static const all = <SchoolRouteSpec>[
    SchoolRouteSpec('52001', 'schoolSettings', '/company/school-settings'),
    SchoolRouteSpec('52002', 'schoolLevels', '/company/school-levels'),
    SchoolRouteSpec('52003', 'schoolRounds', '/company/school-rounds'),
    SchoolRouteSpec('52004', 'schoolHolidays', '/company/school-holidays'),
    SchoolRouteSpec('52005', 'schoolAcademics', '/company/school-academics'),
    SchoolRouteSpec('52006', 'schoolStudents', '/company/school-students'),
    SchoolRouteSpec('52007', 'schoolGuardians', '/company/school-guardians'),
    SchoolRouteSpec('52008', 'schoolAttendance', '/company/school-attendance'),
    SchoolRouteSpec('52009', 'schoolRollCall', '/company/school-roll-call'),
    SchoolRouteSpec('52010', 'schoolNews', '/company/school-news'),
    SchoolRouteSpec(
      '52011',
      'schoolDailyReport',
      '/company/school-daily-report',
    ),
    SchoolRouteSpec(
      '52012',
      'schoolPeriodReport',
      '/company/school-period-report',
    ),
    SchoolRouteSpec('52013', 'schoolDashboard', '/company/school-dashboard'),
    SchoolRouteSpec(
      '52014',
      'schoolGuardianPortal',
      '/company/school-guardian-portal',
    ),
  ];
}
