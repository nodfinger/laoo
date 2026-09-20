import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

List<GoRoute> buildVisitorFeatureRoutes() => <GoRoute>[
  GoRoute(
    path: '/visitor/system-settings',
    name: 'visitorSystemSettings',
    builder: (context, state) => const _VisitorSettingsPreviewPage(),
  ),
];

class _VisitorSettingsPreviewPage extends StatelessWidget {
  const _VisitorSettingsPreviewPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('?????????????????????????????????????')),
  );
}
