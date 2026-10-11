import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/features/inventory/pages/employee_borrow_page.dart';

void main() {
  for (final menuCode in ['08008', '08009', '08010', '08011']) {
    testWidgets('borrow menu $menuCode opens in a material workspace', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: EmployeeBorrowPage(menuCode: menuCode)),
      );
      expect(find.byType(Scaffold), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
