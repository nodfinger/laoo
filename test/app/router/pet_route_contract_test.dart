import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo/app/router/app_router.dart';
import 'package:laoo_pet/pet_feature.dart';

void main() {
  test('Pet 62001–62010 map once to Center and company navigation', () {
    final routes = PetRoutes.all;
    expect(routes, hasLength(10));
    expect(routes.map((r) => r.menuCode).toSet(), hasLength(10));
    expect(routes.map((r) => r.routeName).toSet(), hasLength(10));
    expect(routes.map((r) => r.routePath).toSet(), hasLength(10));
    expect(buildPetRoutes(), hasLength(10));

    final centerPaths = appRouter.configuration.routes
        .whereType<GoRoute>()
        .map((r) => r.path)
        .toSet();
    for (final route in routes) {
      final nav = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(nav, isNotNull, reason: route.menuCode);
      expect(nav!.path, route.routePath);
      expect(nav.goRouteName, route.routeName);
      expect(centerPaths, contains(route.routePath));
    }
  });
}
