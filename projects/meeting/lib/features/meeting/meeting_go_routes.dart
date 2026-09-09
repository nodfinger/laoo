import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'meeting_feature_host.dart';
import 'meeting_route_contract.dart';
import 'pages/meeting_building_page.dart';
import 'pages/meeting_facility_page.dart';
import 'pages/meeting_food_page.dart';
import 'pages/meeting_food_plan_page.dart';
import 'pages/meeting_food_order_summary_page.dart';
import 'pages/meeting_attendance_page.dart';
import 'pages/meeting_invitation_page.dart';
import 'pages/meeting_room_approval_page.dart';
import 'pages/meeting_room_booking_page.dart';
import 'pages/meeting_room_page.dart';

List<GoRoute> buildMeetingFeatureRoutes() => [
  GoRoute(
    path: MeetingRoutePaths.bookings,
    name: MeetingRouteNames.bookings,
    builder: (context, state) => const MeetingRoomBookingPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.foodOrderSummary,
    name: MeetingRouteNames.foodOrderSummary,
    builder: (context, state) => const MeetingFoodOrderSummaryPage(),
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
  _placeholder(MeetingRoutes.roomCheckIn, 'เช็กอินและคืนห้อง'),
  _placeholder(MeetingRoutes.roomSupportTasks, 'งานเตรียมห้องและอุปกรณ์'),
  _placeholder(MeetingRoutes.roomIssues, 'แจ้งปัญหาห้องประชุม'),
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
    path: MeetingRoutePaths.facilities,
    name: MeetingRouteNames.facilities,
    builder: (context, state) => const MeetingFacilityPage(),
  ),
  GoRoute(
    path: MeetingRoutePaths.foods,
    name: MeetingRouteNames.foods,
    builder: (context, state) => const MeetingFoodPage(),
  ),
  _placeholder(MeetingRoutes.utilizationReport, 'รายงานการใช้ห้อง'),
  _placeholder(MeetingRoutes.noShowReport, 'รายงาน No-show'),
  _placeholder(MeetingRoutes.feedbackReport, 'ผลประเมินห้องประชุม'),
];

GoRoute _placeholder(MeetingRouteSpec route, String title) => GoRoute(
  path: route.path,
  name: route.name,
  builder: (context, state) => buildMeetingWorkspaceShell(
    pageTitle: title,
    activeMenu: route.name,
    child: Center(child: Text('$title จะพัฒนาต่อในขั้นตอนถัดไป')),
  ),
);
