import 'package:go_router/go_router.dart';

import 'meeting_route_contract.dart';
import 'pages/meeting_building_page.dart';
import 'pages/meeting_food_page.dart';
import 'pages/meeting_food_plan_page.dart';
import 'pages/meeting_food_order_summary_page.dart';
import 'pages/meeting_food_distribution_page.dart';
import 'pages/meeting_attendance_page.dart';
import 'pages/meeting_invitation_page.dart';
import 'pages/meeting_room_approval_page.dart';
import 'pages/meeting_room_booking_page.dart';
import 'pages/meeting_room_page.dart';
import 'pages/meeting_room_issue_page.dart';
import 'pages/meeting_equipment_request_page.dart';
import 'pages/meeting_system_settings_page.dart';
import 'pages/meeting_room_support_tasks_clean_page.dart';
import 'pages/meeting_room_usage_pages.dart';
import 'pages/meeting_feedback_report_page.dart';

List<GoRoute> buildMeetingFeatureRoutes() => [
  GoRoute(
    path: MeetingRoutePaths.bookings,
    name: MeetingRouteNames.bookings,
    builder: (context, state) => const MeetingRoomBookingPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.equipmentRequests,
    name: MeetingRouteNames.equipmentRequests,
    builder: (context, state) => const MeetingEquipmentRequestPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.systemSettings,
    name: MeetingRouteNames.systemSettings,
    builder: (context, state) => const MeetingSystemSettingsPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.foodOrderSummary,
    name: MeetingRouteNames.foodOrderSummary,
    builder: (context, state) => const MeetingFoodOrderSummaryPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.foodDistribution,
    name: MeetingRouteNames.foodDistribution,
    builder: (context, state) => const MeetingFoodDistributionPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.attendance,
    name: MeetingRouteNames.attendance,
    builder: (context, state) => const MeetingAttendancePage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.approvals,
    name: MeetingRouteNames.approvals,
    builder: (context, state) => const MeetingRoomApprovalPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.calendar,
    name: MeetingRouteNames.calendar,
    builder: (context, state) => const MeetingRoomBookingPage(
      initialCalendar: true,
      menuCode: MeetingMenuCodes.calendar,
    ),
  ),
  GoRoute(
    path: MeetingRoutePaths.invitations,
    name: MeetingRouteNames.invitations,
    builder: (context, state) => const MeetingInvitationPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.foodPlans,
    name: MeetingRouteNames.foodPlans,
    builder: (context, state) => const MeetingFoodPlanPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.roomCheckIn,
    name: MeetingRouteNames.roomCheckIn,
    builder: (context, state) => const MeetingRoomUsagePage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.roomSupportTasks,
    name: MeetingRouteNames.roomSupportTasks,
    builder: (context, state) => const MeetingRoomSupportTasksCleanPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.roomIssues,
    name: MeetingRouteNames.roomIssues,
    builder: (context, state) => const MeetingRoomIssuePage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.buildings,
    name: MeetingRouteNames.buildings,
    builder: (context, state) => const MeetingBuildingPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.rooms,
    name: MeetingRouteNames.rooms,
    builder: (context, state) => const MeetingRoomPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.foods,
    name: MeetingRouteNames.foods,
    builder: (context, state) => const MeetingFoodPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.utilizationReport,
    name: MeetingRouteNames.utilizationReport,
    builder: (context, state) => const MeetingUtilizationReportPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.noShowReport,
    name: MeetingRouteNames.noShowReport,
    builder: (context, state) => const MeetingNoShowReportPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.feedbackReport,
    name: MeetingRouteNames.feedbackReport,
    builder: (context, state) => const MeetingFeedbackReportPage(),
  ),
];
