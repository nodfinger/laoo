class MeetingRouteSpec {
  const MeetingRouteSpec({
    required this.menuCode,
    required this.screenType,
    required this.name,
    required this.path,
  });

  final String menuCode;
  final int screenType;
  final String name;
  final String path;
}

abstract final class MeetingRouteNames {
  static const bookings = 'meetingRoomBookings';
  static const calendar = 'meetingRoomCalendar';
  static const invitations = 'meetingInvitationRsvp';
  static const approvals = 'meetingRoomApprovals';
  static const foodPlans = 'meetingFoodPlans';
  static const roomCheckIn = 'roomCheckIn';
  static const roomSupportTasks = 'roomSupportTasks';
  static const roomIssues = 'roomIssues';
  static const buildings = 'meetingBuildings';
  static const rooms = 'meetingRooms';
  static const facilities = 'meetingFacilities';
  static const foods = 'meetingFoods';
  static const utilizationReport = 'meetingRoomUtilizationReport';
  static const noShowReport = 'meetingNoShowReport';
  static const feedbackReport = 'meetingFeedbackReport';
}

abstract final class MeetingMenuCodes {
  static const bookings = '21001';
  static const calendar = '21002';
  static const invitations = '21003';
  static const approvals = '21004';
  static const foodPlans = '21005';
  static const roomCheckIn = '22001';
  static const roomSupportTasks = '22002';
  static const roomIssues = '22003';
  static const buildings = '23001';
  static const rooms = '23002';
  static const facilities = '23003';
  static const foods = '23004';
  static const utilizationReport = '24001';
  static const noShowReport = '24002';
  static const feedbackReport = '24003';
}

abstract final class MeetingRoutePaths {
  static const bookings = '/company/meeting-room-bookings';
  static const calendar = '/company/meeting-room-calendar';
  static const invitations = '/company/meeting-invitations';
  static const approvals = '/company/meeting-room-approvals';
  static const foodPlans = '/company/meeting-food-plans';
  static const roomCheckIn = '/company/room-check-in';
  static const roomSupportTasks = '/company/room-support-tasks';
  static const roomIssues = '/company/room-issues';
  static const buildings = '/company/meeting-buildings';
  static const rooms = '/company/meeting-rooms';
  static const facilities = '/company/meeting-facilities';
  static const foods = '/company/meeting-foods';
  static const utilizationReport = '/company/reports/meeting-room-utilization';
  static const noShowReport = '/company/reports/meeting-no-show';
  static const feedbackReport = '/company/reports/meeting-feedback';
}

abstract final class MeetingRoutes {
  static const bookings = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.bookings,
    screenType: 1,
    name: MeetingRouteNames.bookings,
    path: MeetingRoutePaths.bookings,
  );
  static const calendar = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.calendar,
    screenType: 3,
    name: MeetingRouteNames.calendar,
    path: MeetingRoutePaths.calendar,
  );
  static const invitations = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.invitations,
    screenType: 2,
    name: MeetingRouteNames.invitations,
    path: MeetingRoutePaths.invitations,
  );
  static const approvals = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.approvals,
    screenType: 2,
    name: MeetingRouteNames.approvals,
    path: MeetingRoutePaths.approvals,
  );
  static const foodPlans = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.foodPlans,
    screenType: 1,
    name: MeetingRouteNames.foodPlans,
    path: MeetingRoutePaths.foodPlans,
  );
  static const roomCheckIn = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.roomCheckIn,
    screenType: 2,
    name: MeetingRouteNames.roomCheckIn,
    path: MeetingRoutePaths.roomCheckIn,
  );
  static const roomSupportTasks = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.roomSupportTasks,
    screenType: 2,
    name: MeetingRouteNames.roomSupportTasks,
    path: MeetingRoutePaths.roomSupportTasks,
  );
  static const roomIssues = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.roomIssues,
    screenType: 1,
    name: MeetingRouteNames.roomIssues,
    path: MeetingRoutePaths.roomIssues,
  );
  static const buildings = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.buildings,
    screenType: 1,
    name: MeetingRouteNames.buildings,
    path: MeetingRoutePaths.buildings,
  );
  static const rooms = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.rooms,
    screenType: 1,
    name: MeetingRouteNames.rooms,
    path: MeetingRoutePaths.rooms,
  );
  static const facilities = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.facilities,
    screenType: 1,
    name: MeetingRouteNames.facilities,
    path: MeetingRoutePaths.facilities,
  );
  static const foods = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.foods,
    screenType: 1,
    name: MeetingRouteNames.foods,
    path: MeetingRoutePaths.foods,
  );
  static const utilizationReport = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.utilizationReport,
    screenType: 3,
    name: MeetingRouteNames.utilizationReport,
    path: MeetingRoutePaths.utilizationReport,
  );
  static const noShowReport = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.noShowReport,
    screenType: 3,
    name: MeetingRouteNames.noShowReport,
    path: MeetingRoutePaths.noShowReport,
  );
  static const feedbackReport = MeetingRouteSpec(
    menuCode: MeetingMenuCodes.feedbackReport,
    screenType: 3,
    name: MeetingRouteNames.feedbackReport,
    path: MeetingRoutePaths.feedbackReport,
  );

  static const all = <MeetingRouteSpec>[
    bookings,
    calendar,
    invitations,
    approvals,
    foodPlans,
    roomCheckIn,
    roomSupportTasks,
    roomIssues,
    buildings,
    rooms,
    facilities,
    foods,
    utilizationReport,
    noShowReport,
    feedbackReport,
  ];
}
