import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'survey_route_contract.dart';

List<GoRoute> buildSurveyFeatureRoutes() => <GoRoute>[
  GoRoute(
    path: SurveyRoutePaths.settings,
    name: SurveyRouteNames.settings,
    builder: (context, state) => const _SettingsPreviewPage(),
  ),
];

class _SettingsPreviewPage extends StatelessWidget {
  const _SettingsPreviewPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('กำลังเตรียมหน้าตั้งค่าระบบแบบสอบถาม')),
  );
}
