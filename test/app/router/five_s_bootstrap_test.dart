import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_five_s/five_s_feature.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';

void main() {
  test('5S has all approved route contracts but no active routes', () {
    expect(FiveSProject.code, 'LAOO_5S');
    expect(FiveSRoutes.all, hasLength(9));
    expect(
      FiveSRoutes.all.map((route) => route.menuCode),
      orderedEquals(const <String>[
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
    expect(buildFiveSFeatureRoutes(), isEmpty);
    for (final route in FiveSRoutes.all) {
      final mappedRoute = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mappedRoute, isNotNull);
      expect(mappedRoute!.databaseRouteName, route.routeName);
      expect(mappedRoute.goRouteName, route.routeName);
      expect(mappedRoute.path, route.routePath);
      expect(mappedRoute.scope, AppMenuScope.company);
    }
  });
}
