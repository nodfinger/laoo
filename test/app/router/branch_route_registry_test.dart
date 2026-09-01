import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';

void main() {
  test('support branch MenuCode resolves to the support Branch route', () {
    final spec = AppMenuRouteRegistry.byMenuCode('01003');

    expect(spec, isNotNull);
    expect(spec!.databaseRouteName, 'branch');
    expect(spec.scope, AppMenuScope.support);
  });

  test('company branch MenuCode resolves to the shared Branch route', () {
    final spec = AppMenuRouteRegistry.byMenuCode('09002');

    expect(spec, isNotNull);
    expect(spec!.databaseRouteName, 'companyBranches');
    expect(spec.scope, AppMenuScope.company);
  });
}
