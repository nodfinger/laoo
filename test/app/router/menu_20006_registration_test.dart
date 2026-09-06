import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo/app/router/route_names.dart';
import 'package:laoo/app/router/route_paths.dart';

void main() {
  test('menu 20006 is registered as the complaint portal route', () {
    final spec = AppMenuRouteRegistry.byMenuCode('20006');

    expect(spec, isNotNull);
    expect(spec!.databaseRouteName, 'portalComplaint');
    expect(spec.goRouteName, RouteNames.portalComplaint);
    expect(spec.path, RoutePaths.portalComplaint);
    expect(spec.scope, AppMenuScope.company);
  });
}
