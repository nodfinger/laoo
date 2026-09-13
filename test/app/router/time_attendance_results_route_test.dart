import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo/app/router/route_names.dart';
import 'package:laoo/app/router/route_paths.dart';

void main() {
  test(
    'daily attendance results remains a company-scoped Core route contract',
    () {
      final spec = AppMenuRouteRegistry.byMenuCode('25002');

      expect(spec, isNotNull);
      expect(spec!.databaseRouteName, 'timeAttendanceResults');
      expect(spec.goRouteName, RouteNames.timeAttendanceResults);
      expect(spec.path, RoutePaths.timeAttendanceResults);
      expect(spec.scope, AppMenuScope.company);
    },
  );
}
