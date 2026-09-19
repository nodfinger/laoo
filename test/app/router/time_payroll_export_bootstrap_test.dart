import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo/app/router/route_names.dart';
import 'package:laoo/app/router/route_paths.dart';

void main() {
  test('Time payroll export menu contracts are registered', () {
    final expected = <String, (String, String, String)>{
      '28013': (
        RouteNames.timePayrollExportProfiles,
        RoutePaths.timePayrollExportProfiles,
        'timePayrollExportProfiles',
      ),
      '25003': (
        RouteNames.timePayrollExport,
        RoutePaths.timePayrollExport,
        'timePayrollExport',
      ),
      '25004': (
        RouteNames.timePayrollExportHistory,
        RoutePaths.timePayrollExportHistory,
        'timePayrollExportHistory',
      ),
    };

    for (final entry in expected.entries) {
      final route = AppMenuRouteRegistry.byMenuCode(entry.key);
      expect(route, isNotNull);
      expect(route!.databaseRouteName, entry.value.$3);
      expect(route.goRouteName, entry.value.$1);
      expect(route.path, entry.value.$2);
    }
  });
}
