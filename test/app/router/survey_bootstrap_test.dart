import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo_survey/survey_feature.dart';

void main() {
  test('Survey has all approved contracts but no active routes', () {
    expect(SurveyProject.code, 'LAOO_SURVEY');
    expect(SurveyRoutes.all, hasLength(6));
    expect(
      SurveyRoutes.all.map((route) => route.menuCode),
      orderedEquals(const <String>[
        '40001',
        '40002',
        '40003',
        '40004',
        '40005',
        '40006',
      ]),
    );
    expect(SurveyRoutes.implemented, isEmpty);
    expect(buildSurveyFeatureRoutes(), isEmpty);
    for (final route in SurveyRoutes.all) {
      final mapped = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mapped, isNotNull);
      expect(mapped!.databaseRouteName, route.routeName);
      expect(mapped.goRouteName, route.routeName);
      expect(mapped.path, route.routePath);
    }
  });
}
