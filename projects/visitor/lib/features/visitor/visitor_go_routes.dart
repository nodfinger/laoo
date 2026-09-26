import 'package:go_router/go_router.dart';

import 'visitor_check_in_page.dart';
import 'visitor_contact_points_page.dart';
import 'visitor_history_page.dart';
import 'visitor_appointments_page.dart';
import 'visitor_host_confirm_page.dart';
import 'visitor_inside_page.dart';
import 'visitor_system_settings_page.dart';

List<GoRoute> buildVisitorFeatureRoutes() => <GoRoute>[
  GoRoute(path: '/visitor/pre-register', name: 'preRegister', builder: (context, state) => const VisitorAppointmentsPage()),
  GoRoute(path: '/visitor/approval-status', name: 'approvalStatus', builder: (context, state) => const VisitorAppointmentApprovalsPage()),
  GoRoute(
    path: '/visitor/host-confirm',
    name: 'hostConfirm',
    builder: (context, state) => const VisitorHostConfirmPage(),
  ),
  GoRoute(
    path: '/visitor/site-zone-gate',
    name: 'siteZoneGate',
    builder: (context, state) => const VisitorContactPointsPage(),
  ),
  GoRoute(
    path: '/visitor/system-settings',
    name: 'visitorSystemSettings',
    builder: (context, state) => const VisitorSystemSettingsPage(),
  ),
  GoRoute(
    path: '/visitor/check-in',
    name: 'visitorCheckIn',
    builder: (context, state) => state.uri.queryParameters['action'] == 'new'
        ? const VisitorCheckInPage()
        : const VisitorInsidePage(),
  ),
  GoRoute(
    path: '/visitor/check-in/new',
    name: 'visitorCheckInNew',
    builder: (context, state) => const VisitorCheckInPage(),
  ),
  GoRoute(
    path: '/visitor/inside',
    name: 'visitorInside',
    builder: (context, state) => const VisitorInsidePage(),
  ),
  GoRoute(
    path: '/visitor/check-out',
    name: 'gateCheckOut',
    builder: (context, state) => const VisitorInsidePage(),
  ),
  GoRoute(
    path: '/visitor/history',
    name: 'visitorHistory',
    builder: (context, state) => const VisitorHistoryPage(),
  ),
];
