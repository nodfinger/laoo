import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo_evaluation/evaluation_feature.dart';

void main() {
  test('Evaluation has all approved contracts but no active routes', () {
    expect(EvaluationProject.code, 'LAOO_EVALUATION');
    expect(EvaluationRoutes.all, hasLength(7));
    expect(EvaluationRoutes.implemented, isEmpty);
    expect(buildEvaluationFeatureRoutes(), isEmpty);
    for (final route in EvaluationRoutes.all) {
      final mapped = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mapped, isNotNull);
      expect(mapped!.databaseRouteName, route.routeName);
      expect(mapped.goRouteName, route.routeName);
      expect(mapped.path, route.routePath);
    }
  });
}
