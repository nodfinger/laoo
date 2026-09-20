import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pos_route_contract.dart';

List<GoRoute> buildPosFeatureRoutes() => <GoRoute>[
  GoRoute(
    path: PosRoutePaths.settings,
    name: PosRouteNames.settings,
    builder: (context, state) => const _SettingsPreviewPage(),
  ),
];

class _SettingsPreviewPage extends StatelessWidget {
  const _SettingsPreviewPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('กำลังเตรียมหน้าตั้งค่าระบบ POS')),
  );
}
