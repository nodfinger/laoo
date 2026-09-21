import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'visitor_check_in_page.dart';
import 'visitor_contact_points_page.dart';
import 'visitor_system_settings_page.dart';

List<GoRoute> buildVisitorFeatureRoutes() => <GoRoute>[
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
    builder: (context, state) => const VisitorCheckInPage(),
  ),
];
