import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_expense/expense_feature.dart';

void main() {
  test(
    'expense route contract implements all nine menus with database screen types',
    () {
      expect(ExpenseRoutes.all.map((e) => e.menuCode).toList(), [
        '41001',
        '41002',
        '41003',
        '41004',
        '41005',
        '41006',
        '41007',
        '41008',
        '41009',
      ]);
      expect(ExpenseRoutes.all.map((e) => e.screenType).toList(), [
        2,
        1,
        4,
        4,
        3,
        2,
        4,
        3,
        4,
      ]);
      expect(ExpenseRoutes.all.every((e) => e.isImplemented), isTrue);
    },
  );
  test('expense routes are unique', () {
    expect(ExpenseRoutes.all.map((e) => e.routePath).toSet().length, 9);
    expect(ExpenseRoutes.all.map((e) => e.routeName).toSet().length, 9);
  });
}
