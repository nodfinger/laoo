import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_visitor/core/config/app_config.dart';
import 'package:laoo_visitor/main.dart';

void main() {
  test('Visitor defaults use the reserved project and API ports', () {
    expect(AppConfig.projectCode, 'LAOO_VISITOR');
    expect(AppConfig.apiBaseUrl, 'http://localhost:5082');
    expect(LaooOwnerScope.values, hasLength(3));
  });

  testWidgets('Visitor bootstrap opens without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const LaooVisitorApp());
    await tester.pumpAndSettle();

    expect(find.text('ระบบผู้มาติดต่อ'), findsOneWidget);
    expect(find.text('LAOO Visitor พร้อมสำหรับเริ่มพัฒนา'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
