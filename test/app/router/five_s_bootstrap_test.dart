import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo_five_s/five_s_feature.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';

void main() {
  test('5S has all approved route contracts and preview routes', () {
    expect(FiveSProject.code, 'LAOO_5S');
    expect(FiveSRoutes.all, hasLength(10));
    expect(
      FiveSRoutes.all.map((route) => route.menuCode),
      orderedEquals(const <String>[
        '39010',
        '39001',
        '39002',
        '39003',
        '39004',
        '39005',
        '39006',
        '39007',
        '39008',
        '39009',
      ]),
    );
    expect(FiveSRoutes.implemented, isEmpty);
    final previewRoutes = buildFiveSFeatureRoutes();
    expect(previewRoutes, hasLength(FiveSRoutes.all.length));
    for (final route in FiveSRoutes.all) {
      expect(
        previewRoutes.where(
          (preview) =>
              preview.name == route.routeName &&
              preview.path == route.routePath,
        ),
        hasLength(1),
      );
      final mappedRoute = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mappedRoute, isNotNull);
      expect(mappedRoute!.databaseRouteName, route.routeName);
      expect(mappedRoute.goRouteName, route.routeName);
      expect(mappedRoute.path, route.routePath);
      expect(mappedRoute.scope, AppMenuScope.company);
    }
  });

  testWidgets('every 5S route opens a readable preview page', (tester) async {
    final router = GoRouter(
      initialLocation: FiveSRoutes.all.first.routePath,
      routes: buildFiveSFeatureRoutes(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    for (final route in FiveSRoutes.all) {
      router.go(route.routePath);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, route.routePath);
      expect(find.text('กำลังเตรียมหน้าจอระบบตรวจ 5ส'), findsOneWidget);
    }
  });
}
