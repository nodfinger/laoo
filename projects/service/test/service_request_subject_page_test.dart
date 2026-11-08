import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/core/api/api_client.dart';
import 'package:laoo_service/features/service_request_subject/pages/service_request_subject_page.dart';
import 'package:laoo_service/features/support/presentation/widgets/support_workspace_shell.dart';

void main() {
  setUpAll(
    () => configureServiceWorkspaceShell(
      ({required pageTitle, required activeMenu, required child}) =>
          Scaffold(body: child),
    ),
  );

  testWidgets('subject list shows shared rows read-only and company actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: ServiceRequestSubjectPage(api: _FakeApi())),
    );
    await tester.pumpAndSettle();
    expect(find.text('หัวข้อส่วนกลาง'), findsOneWidget);
    expect(find.text('หัวข้อบริษัท'), findsOneWidget);
    expect(find.byTooltip('แก้ไข'), findsOneWidget);
    expect(find.byTooltip('ลบ'), findsOneWidget);
    await tester.tap(find.byTooltip('แสดงแบบการ์ด'));
    await tester.pumpAndSettle();
    expect(find.text('หัวข้อบริษัท'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('approval filter and popup transmit the selected value', (
    tester,
  ) async {
    final api = _FakeApi();
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: ServiceRequestSubjectPage(api: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทั้งหมด'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ต้องอนุมัติ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ค้นหา'));
    await tester.pumpAndSettle();
    expect(api.lastQuery?['requiresApproval'], 'true');
    await tester.tap(find.text('เพิ่ม'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ชื่อหัวข้อ *'),
      'หัวข้อใหม่',
    );
    await tester.tap(find.text('ต้องขออนุมัติก่อนดำเนินการ'));
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect((api.lastBody as Map)['requiresApproval'], true);
  });
}

class _FakeApi extends ApiClient {
  Map<String, String>? lastQuery;
  Object? lastBody;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/actions')) {
      return {'view': true, 'create': true, 'edit': true, 'delete': true};
    }
    lastQuery = query;
    return [
      {
        'id': 1,
        'name': 'หัวข้อส่วนกลาง',
        'seq': 1,
        'isShared': true,
        'isActive': true,
      },
      {
        'id': 2,
        'name': 'หัวข้อบริษัท',
        'seq': 2,
        'isShared': false,
        'isActive': true,
      },
    ];
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    lastBody = body;
    return {'id': 3};
  }
}
