import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'gate_pass_route_contract.dart';

List<GoRoute> buildGatePassFeatureRoutes() => <GoRoute>[
  GoRoute(
    path: GatePassRoutePaths.settings,
    name: GatePassRouteNames.settings,
    builder: (context, state) => const _GatePassPreviewPage(),
  ),
  GoRoute(
    path: GatePassRoutePaths.purposes,
    name: GatePassRouteNames.purposes,
    builder: (context, state) => const _GatePassPreviewPage(),
  ),
  GoRoute(
    path: GatePassRoutePaths.requests,
    name: GatePassRouteNames.requests,
    builder: (context, state) => const _GatePassPreviewPage(),
  ),
  GoRoute(
    path: GatePassRoutePaths.approvalInbox,
    name: GatePassRouteNames.approvalInbox,
    builder: (context, state) => const _GatePassPreviewPage(),
  ),
  GoRoute(
    path: GatePassRoutePaths.exitCheck,
    name: GatePassRouteNames.exitCheck,
    builder: (context, state) => const _GatePassPreviewPage(),
  ),
  GoRoute(
    path: GatePassRoutePaths.returnTracking,
    name: GatePassRouteNames.returnTracking,
    builder: (context, state) => const _GatePassPreviewPage(),
  ),
  GoRoute(
    path: GatePassRoutePaths.myGatePasses,
    name: GatePassRouteNames.myGatePasses,
    builder: (context, state) => const _GatePassPreviewPage(),
  ),
  GoRoute(
    path: GatePassRoutePaths.reports,
    name: GatePassRouteNames.reports,
    builder: (context, state) => const _GatePassPreviewPage(),
  ),
];

class _GatePassPreviewPage extends StatelessWidget {
  const _GatePassPreviewPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('กำลังเตรียมหน้าจอ')));
}
