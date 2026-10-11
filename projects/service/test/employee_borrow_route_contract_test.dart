import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/service_feature.dart';

void main() {
  const expected = <String, (int, String, String)>{
    '08008': (4, 'employeeBorrowRequests', '/inventory/borrow-requests'),
    '08009': (3, 'employeeBorrowApprovals', '/inventory/borrow-approvals'),
    '08010': (4, 'employeeBorrowTransfers', '/inventory/borrow-transfers'),
    '08011': (3, 'employeeBorrowHistory', '/inventory/borrow-history'),
  };

  test('employee borrow routes match the Core menu contract', () {
    for (final entry in expected.entries) {
      final route = ServiceRoutes.byMenuCode(entry.key);
      expect(route.projectCode, 'LAOO');
      expect(route.screenType, entry.value.$1);
      expect(route.routeName, entry.value.$2);
      expect(route.routePath, entry.value.$3);
    }
  });
}
