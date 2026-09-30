import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_five_s/five_s_feature.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';

void main() {
  test('5S has all approved and implemented route contracts', () {
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
    expect(FiveSRoutes.implemented, hasLength(10));
    final featureRoutes = buildFiveSFeatureRoutes();
    expect(featureRoutes, hasLength(FiveSRoutes.all.length));
    for (final route in FiveSRoutes.all) {
      expect(
        featureRoutes.where(
          (feature) =>
              feature.name == route.routeName &&
              feature.path == route.routePath,
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

  test('5S routes no longer expose a placeholder contract', () {
    expect(FiveSRoutes.all.every((route) => route.isImplemented), isTrue);
    expect(
      buildFiveSFeatureRoutes().map((route) => route.name),
      containsAll(FiveSRoutes.all.map((route) => route.routeName)),
    );
  });
}
