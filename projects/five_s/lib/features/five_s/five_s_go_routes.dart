import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'five_s_route_contract.dart';

List<GoRoute> buildFiveSFeatureRoutes() => FiveSRoutes.all
    .map(
      (route) => GoRoute(
        path: route.routePath,
        name: route.routeName,
        builder: (context, state) => const _FiveSPreviewPage(),
      ),
    )
    .toList(growable: false);

class _FiveSPreviewPage extends StatelessWidget {
  const _FiveSPreviewPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('กำลังเตรียมหน้าจอระบบตรวจ 5ส')));
}
