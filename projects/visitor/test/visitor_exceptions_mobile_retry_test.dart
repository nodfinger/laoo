import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_visitor/core/api/visitor_api_client.dart';
import 'package:laoo_visitor/features/visitor/visitor_exceptions_page.dart';
import 'package:laoo_visitor/features/visitor/visitor_feature_host.dart';

void main() {
  testWidgets('34003 narrow error retry loads show-only exception cards', (
    tester,
  ) async {
    final api = _VisitorExceptionsApi();
    configureVisitorFeatureHost(
      ({required pageTitle, required activeMenu, required child}) => child,
    );
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisitorExceptionsPage(apiClient: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('รายละเอียดเพิ่มเติม'), findsOneWidget);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
    expect(find.text('ไม่พบรายการผิดปกติ'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(api.actionCalls, 2);
    expect(find.text('ลองอีกครั้ง'), findsNothing);
    expect(find.text('ผู้มาติดต่อทดสอบ'), findsOneWidget);
    expect(find.text('ดูรายละเอียด'), findsOneWidget);
    expect(find.text('แก้ไข'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _VisitorExceptionsApi extends VisitorApiClient {
  int actionCalls = 0;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path == '/api/visitor/exceptions/actions') {
      actionCalls++;
      if (actionCalls == 1) {
        throw const VisitorApiException(503, 'ระบบขัดข้องชั่วคราว');
      }
      return {'caption': 'รายการผิดปกติ', 'view': true};
    }
    if (path == '/api/visitor/exceptions') {
      return {
        'page': 1,
        'pageSize': 20,
        'total': 1,
        'items': [
          {
            'visitorVisitId': 19,
            'visitorName': 'ผู้มาติดต่อทดสอบ',
            'hostName': 'ผู้รับรอง',
            'contactPointName': 'จุดติดต่อ',
            'occurredDate': '2026-09-29T10:00:00',
            'exceptionType': 'HOST_CONFIRMATION_PENDING',
            'exceptionDescription': 'รอยืนยันการเข้าพบ',
          },
        ],
      };
    }
    throw StateError('Unexpected GET path');
  }
}
