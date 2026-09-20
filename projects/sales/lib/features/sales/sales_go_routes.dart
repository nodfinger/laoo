import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'sales_route_contract.dart';

List<GoRoute> buildSalesFeatureRoutes() => <GoRoute>[
  GoRoute(
    path: SalesRoutePaths.settings,
    name: SalesRouteNames.settings,
    builder: (context, state) => const _SettingsPreviewPage(),
  ),
];

class _SettingsPreviewPage extends StatelessWidget {
  const _SettingsPreviewPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('กำลังเตรียมหน้าตั้งค่าระบบขาย')),
  );
}
