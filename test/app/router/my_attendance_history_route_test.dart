import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo/app/router/route_names.dart';
import 'package:laoo/app/router/route_paths.dart';

void main() {
  test('my attendance history retains the Core Time route contract', () {
    final spec = AppMenuRouteRegistry.byMenuCode('30002');

    expect(spec, isNotNull);
    expect(spec!.databaseRouteName, 'myAttendanceHistory');
    expect(spec.goRouteName, RouteNames.myAttendanceHistory);
    expect(spec.path, RoutePaths.myAttendanceHistory);
    expect(spec.scope, AppMenuScope.company);
  });
}
