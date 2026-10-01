import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo_sales/sales_feature.dart';

void main() {
  test('Sales has all approved contracts and active routes', () {
    expect(SalesProject.code, 'LAOO_SALES');
    expect(SalesRoutes.all, hasLength(7));
    expect(SalesRoutes.implemented, hasLength(7));
    expect(buildSalesFeatureRoutes(), hasLength(7));
    for (final route in SalesRoutes.all) {
      final mapped = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mapped, isNotNull);
      expect(mapped!.databaseRouteName, route.routeName);
      expect(mapped.goRouteName, route.routeName);
      expect(mapped.path, route.routePath);
    }
  });
}
