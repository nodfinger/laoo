import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo_intranet/intranet_feature.dart';

void main() {
  test('Intranet has all approved contracts but no active routes', () {
    expect(IntranetProject.code, 'LAOO_INTRANET');
    expect(IntranetRoutes.all, hasLength(5));
    expect(
      IntranetRoutes.all.map((route) => route.menuCode),
      orderedEquals(const <String>[
        '43001',
        '43002',
        '43003',
        '43004',
        '43005',
      ]),
    );
    expect(IntranetRoutes.implemented, isEmpty);
    expect(buildIntranetFeatureRoutes(), isEmpty);
    for (final route in IntranetRoutes.all) {
      final mapped = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mapped, isNotNull);
      expect(mapped!.databaseRouteName, route.routeName);
      expect(mapped.goRouteName, route.routeName);
      expect(mapped.path, route.routePath);
    }
  });
}
