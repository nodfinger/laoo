import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo_project/project_feature.dart';

void main() {
  test('Project has all approved contracts but no active routes', () {
    expect(ProjectManagementProject.code, 'LAOO_PROJECT');
    expect(ProjectRoutes.all, hasLength(5));
    expect(
      ProjectRoutes.all.map((route) => route.menuCode),
      orderedEquals(const <String>[
        '42001',
        '42002',
        '42003',
        '42004',
        '42005',
      ]),
    );
    expect(ProjectRoutes.implemented, isEmpty);
    expect(buildProjectFeatureRoutes(), isEmpty);
    for (final route in ProjectRoutes.all) {
      final mapped = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mapped, isNotNull);
      expect(mapped!.databaseRouteName, route.routeName);
      expect(mapped.goRouteName, route.routeName);
      expect(mapped.path, route.routePath);
    }
  });
}
