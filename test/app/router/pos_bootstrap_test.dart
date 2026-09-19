import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo_pos/pos_feature.dart';

void main() {
  test('POS has all approved contracts but no active routes', () {
    expect(PosProject.code, 'LAOO_POS');
    expect(PosRoutes.all, hasLength(7));
    expect(
      PosRoutes.all.map((route) => route.menuCode),
      orderedEquals(const <String>[
        '46001',
        '46002',
        '46003',
        '46004',
        '46005',
        '46006',
        '46007',
      ]),
    );
    expect(PosRoutes.implemented, isEmpty);
    expect(buildPosFeatureRoutes(), isEmpty);
    for (final route in PosRoutes.all) {
      final mapped = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mapped, isNotNull);
      expect(mapped!.databaseRouteName, route.routeName);
      expect(mapped.goRouteName, route.routeName);
      expect(mapped.path, route.routePath);
    }
  });
}
