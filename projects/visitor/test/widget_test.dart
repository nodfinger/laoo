import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_visitor/core/config/app_config.dart';
import 'package:laoo_visitor/visitor_feature.dart';

void main() {
  test('Visitor uses the Center API and reserved project catalog', () {
    expect(AppConfig.projectCode, 'LAOO_VISITOR');
    expect(AppConfig.apiBaseUrl, 'http://localhost:5080');
    expect(LaooOwnerScope.values, hasLength(3));
    expect(VisitorRoutes.all, hasLength(22));
    expect(VisitorRoutes.implemented, isEmpty);
    expect(buildVisitorFeatureRoutes(), isEmpty);
  });
}
