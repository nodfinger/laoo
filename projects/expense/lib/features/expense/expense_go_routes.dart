import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'expense_route_contract.dart';

List<GoRoute> buildExpenseFeatureRoutes() => <GoRoute>[
  GoRoute(
    path: ExpenseRoutePaths.settings,
    name: ExpenseRouteNames.settings,
    builder: (context, state) => const _SettingsPreviewPage(),
  ),
];

class _SettingsPreviewPage extends StatelessWidget {
  const _SettingsPreviewPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('กำลังเตรียมหน้าตั้งค่าระบบค่าใช้จ่าย')),
  );
}
