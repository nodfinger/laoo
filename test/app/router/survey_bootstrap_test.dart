import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo_survey/survey_feature.dart';

void main() {
  test('Survey has seven implemented route contracts', () {
    expect(SurveyProject.code, 'LAOO_SURVEY');
    expect(SurveyRoutes.all, hasLength(7));
    expect(
      SurveyRoutes.all.map((route) => route.menuCode),
      orderedEquals(const <String>[
        '40001',
        '40002',
        '40003',
        '40004',
        '40005',
        '40006',
        '40007',
      ]),
    );
    expect(SurveyRoutes.implemented, hasLength(7));
    final previewRoutes = buildSurveyFeatureRoutes();
    expect(previewRoutes, hasLength(SurveyRoutes.all.length));
    for (final route in SurveyRoutes.all) {
      expect(
        previewRoutes.where(
          (preview) =>
              preview.name == route.routeName &&
              preview.path == route.routePath,
        ),
        hasLength(1),
      );
      final mapped = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mapped, isNotNull);
      expect(mapped!.databaseRouteName, route.routeName);
      expect(mapped.goRouteName, route.routeName);
      expect(mapped.path, route.routePath);
    }
  });
}
