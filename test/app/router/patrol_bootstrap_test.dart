import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo_patrol/patrol_feature.dart';

void main() {
  test('Patrol exposes all approved routes through the Center host', () {
    expect(PatrolProject.code, 'LAOO_PATROL');
    expect(PatrolRoutes.all, hasLength(12));
    expect(PatrolRoutes.implemented, hasLength(12));
    expect(buildPatrolFeatureRoutes(), hasLength(12));
    expect(
      PatrolRoutes.all.map((route) => route.screenType),
      orderedEquals([2, 1, 1, 1, 1, 1, 4, 4, 3, 3, 3, 3]),
    );
    for (final route in PatrolRoutes.all) {
      final mapped = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mapped, isNotNull);
      expect(mapped!.databaseRouteName, route.routeName);
      expect(mapped.goRouteName, route.routeName);
      expect(mapped.path, route.routePath);
    }
  });
}
