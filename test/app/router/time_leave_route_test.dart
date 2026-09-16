import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo/app/router/route_names.dart';
import 'package:laoo/app/router/route_paths.dart';

void main() {
  const expected = {
    '28009': (
      'timeLeaveTypes',
      RouteNames.timeLeaveTypes,
      RoutePaths.timeLeaveTypes,
    ),
    '28010': (
      'timeLeaveEntitlementPolicies',
      RouteNames.timeLeaveEntitlementPolicies,
      RoutePaths.timeLeaveEntitlementPolicies,
    ),
    '28011': (
      'timeLeaveBalances',
      RouteNames.timeLeaveBalances,
      RoutePaths.timeLeaveBalances,
    ),
    '26003': (
      'timeLeaveRequests',
      RouteNames.timeLeaveRequests,
      RoutePaths.timeLeaveRequests,
    ),
    '26004': (
      'timeLeaveApprovalInbox',
      RouteNames.timeLeaveApprovalInbox,
      RoutePaths.timeLeaveApprovalInbox,
    ),
    '30003': (
      'myLeaveRequests',
      RouteNames.myLeaveRequests,
      RoutePaths.myLeaveRequests,
    ),
    '30004': (
      'myLeaveBalance',
      RouteNames.myLeaveBalance,
      RoutePaths.myLeaveBalance,
    ),
  };

  test('leave menus retain Core Time route contracts', () {
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
