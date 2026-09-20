import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'five_s_route_contract.dart';

List<GoRoute> buildFiveSFeatureRoutes() => <GoRoute>[
  GoRoute(
    path: FiveSRoutePaths.settings,
    name: FiveSRouteNames.settings,
    builder: (context, state) => const _SettingsPreviewPage(),
  ),
];

class _SettingsPreviewPage extends StatelessWidget {
  const _SettingsPreviewPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('?????????????????????????? 5?')),
  );
}
