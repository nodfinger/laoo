import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';

void main() {
  test('Time leave report registry contract is reserved for Time', () {
    final route = AppMenuRouteRegistry.byMenuCode('28012');
    expect(route, isNotNull);
    expect(route!.databaseRouteName, 'timeLeaveReport');
    expect(route.goRouteName, 'timeLeaveReport');
    expect(route.path, '/company/time-leave-report');
  });
}
