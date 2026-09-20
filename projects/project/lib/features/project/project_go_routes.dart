import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'project_route_contract.dart';

List<GoRoute> buildProjectFeatureRoutes() => <GoRoute>[
  GoRoute(
    path: ProjectRoutePaths.settings,
    name: ProjectRouteNames.settings,
    builder: (context, state) => const _SettingsPreviewPage(),
  ),
];

class _SettingsPreviewPage extends StatelessWidget {
  const _SettingsPreviewPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('กำลังเตรียมหน้าตั้งค่าระบบบริหารโครงการ')),
  );
}
