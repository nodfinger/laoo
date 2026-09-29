import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'survey_route_contract.dart';

List<GoRoute> buildSurveyFeatureRoutes() => SurveyRoutes.all
    .map(
      (route) => GoRoute(
        path: route.routePath,
        name: route.routeName,
        builder: (context, state) => const _SurveyPreviewPage(),
      ),
    )
    .toList(growable: false);

class _SurveyPreviewPage extends StatelessWidget {
  const _SurveyPreviewPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('กำลังเตรียมหน้าจอระบบแบบสอบถาม')),
  );
}
