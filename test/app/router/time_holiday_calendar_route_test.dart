import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo/app/router/route_names.dart';
import 'package:laoo/app/router/route_paths.dart';

void main() {
  const expected = {
    '28005': (
      'timeHolidayCalendars',
      RouteNames.timeHolidayCalendars,
      RoutePaths.timeHolidayCalendars,
    ),
    '28006': (
      'timeHolidayDates',
      RouteNames.timeHolidayDates,
      RoutePaths.timeHolidayDates,
    ),
    '28007': (
      'timeBranchHolidayCalendars',
      RouteNames.timeBranchHolidayCalendars,
      RoutePaths.timeBranchHolidayCalendars,
    ),
    '28008': (
      'timeBranchHolidayExceptions',
      RouteNames.timeBranchHolidayExceptions,
      RoutePaths.timeBranchHolidayExceptions,
    ),
  };

  test('holiday calendar menus retain Core route contracts', () {
    for (final entry in expected.entries) {
      final spec = AppMenuRouteRegistry.byMenuCode(entry.key);
      expect(spec, isNotNull);
      expect(spec!.databaseRouteName, entry.value.$1);
      expect(spec.goRouteName, entry.value.$2);
      expect(spec.path, entry.value.$3);
      expect(spec.scope, AppMenuScope.company);
    }
  });
}
