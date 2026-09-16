import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_gate_pass/gate_pass_feature.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';

void main() {
  test('Gate Pass has all approved route contracts but no active routes', () {
    expect(GatePassProject.code, 'LAOO_GATE_PASS');
    expect(GatePassRoutes.all, hasLength(8));
    expect(
      GatePassRoutes.all.map((route) => route.menuCode),
      orderedEquals(const <String>[
        '38001',
        '38002',
        '38003',
        '38004',
        '38005',
        '38006',
        '38007',
        '38008',
      ]),
    );
    expect(GatePassRoutes.implemented, isEmpty);
    expect(buildGatePassFeatureRoutes(), isEmpty);

    for (final route in GatePassRoutes.all) {
      final mappedRoute = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mappedRoute, isNotNull);
      expect(mappedRoute!.databaseRouteName, route.routeName);
      expect(mappedRoute.goRouteName, route.routeName);
      expect(mappedRoute.path, route.routePath);
      expect(mappedRoute.scope, AppMenuScope.company);
    }
  });
}
