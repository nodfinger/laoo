import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo_expense/expense_feature.dart';

void main() {
  test('Expense has approved contracts but no active routes', () {
    expect(ExpenseProject.code, 'LAOO_EXPENSE');
    expect(ExpenseRoutes.all, hasLength(8));
    expect(
      ExpenseRoutes.all.map((route) => route.menuCode),
      orderedEquals(const <String>[
        '41001',
        '41002',
        '41003',
        '41004',
        '41005',
        '41006',
        '41007',
        '41008',
      ]),
    );
    expect(ExpenseRoutes.implemented, isEmpty);
    expect(buildExpenseFeatureRoutes(), isEmpty);
    for (final route in ExpenseRoutes.all) {
      final mapped = AppMenuRouteRegistry.byMenuCode(route.menuCode);
      expect(mapped, isNotNull);
      expect(mapped!.databaseRouteName, route.routeName);
      expect(mapped.goRouteName, route.routeName);
      expect(mapped.path, route.routePath);
    }
  });
}
