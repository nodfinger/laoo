import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/features/service_request/data/service_request_api.dart';
import 'package:laoo_service/features/service_request/pages/service_request_page.dart';
import 'package:laoo_service/features/support/presentation/widgets/support_workspace_shell.dart';

void main() {
  setUpAll(() {
    configureServiceWorkspaceShell(
      ({
        required String pageTitle,
        required String activeMenu,
        required Widget child,
      }) => Scaffold(body: child),
    );
  });

  Future<void> showPage(
    WidgetTester tester,
    _FakeRequestApi api, {
    Size size = const Size(1100, 800),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: ServiceRequestPage(selfService: true, api: api)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('self page hides edit and delete without login permissions', (
    tester,
  ) async {
    final api = _FakeRequestApi();
    await showPage(tester, api);
    expect(find.byTooltip('แก้ไข'), findsNothing);
    expect(find.byTooltip('ลบ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('self page shows edit and delete only on CRUD ScreenType', (
    tester,
  ) async {
    final api = _FakeRequestApi()
      ..canEdit = true
      ..canDelete = true;
    await showPage(tester, api);
    expect(find.byTooltip('แก้ไข'), findsOneWidget);
    expect(find.byTooltip('ลบ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('self page hides mutations when ScreenType is not CRUD', (
    tester,
  ) async {
    final api = _FakeRequestApi()
      ..screenType = 3
      ..canEdit = true
      ..canDelete = true;
    await showPage(tester, api);
    expect(find.byTooltip('แก้ไข'), findsNothing);
    expect(find.byTooltip('ลบ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('self delete confirms and calls owner-scoped API', (
    tester,
  ) async {
    final api = _FakeRequestApi()..canDelete = true;
    await showPage(tester, api);
    await tester.tap(find.byTooltip('ลบ'));
    await tester.pumpAndSettle();
    expect(find.text('ลบแล้วไม่สามารถเรียกคืนได้'), findsOneWidget);
    await tester.tap(find.text('ลบ').last);
    await tester.pumpAndSettle();
    expect(api.deletedId, 42);
    expect(api.deletedAsSelf, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('self edit saves through owner-scoped API', (tester) async {
    final api = _FakeRequestApi()..canEdit = true;
    await showPage(tester, api);
    await tester.tap(find.byTooltip('แก้ไข'));
    await tester.pumpAndSettle();
    expect(find.textContaining('> แก้ไข'), findsOneWidget);
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(api.editedId, 42);
    expect(api.editedAsSelf, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile card keeps self actions without overflow', (
    tester,
  ) async {
    final api = _FakeRequestApi()
      ..canEdit = true
      ..canDelete = true;
    await showPage(tester, api, size: const Size(390, 700));
    expect(find.byTooltip('แก้ไข'), findsOneWidget);
    expect(find.byTooltip('ลบ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRequestApi extends ServiceRequestApi {
  int screenType = 1;
  bool canEdit = false;
  bool canDelete = false;
  int? deletedId;
  bool? deletedAsSelf;
  int? editedId;
  bool? editedAsSelf;

  @override
  Future<Map<String, dynamic>> actions() async => {
    'selfScreenType': screenType,
    'selfCreate': false,
    'selfEdit': canEdit,
    'selfDelete': canDelete,
  };

  @override
  Future<Map<String, dynamic>> list({
    String search = '',
    String status = '',
    bool selfService = false,
    int page = 1,
    String? menuCode,
  }) async => {
    'items': deletedId == null
        ? [
            {
              'requestId': 42,
              'requestNo': 'SR42',
              'requesterName': 'ผู้แจ้ง',
              'subject': 'ไฟไม่ติด',
              'statusCode': 'NEW',
              'requestDate': '2026-09-29',
            },
          ]
        : <Map<String, dynamic>>[],
    'total': deletedId == null ? 1 : 0,
  };

  @override
  Future<Map<String, dynamic>> detail(int id, {String? menuCode}) async => {
    'requestId': id,
    'requestNo': 'SR42',
    'requesterName': 'ผู้แจ้ง',
    'subject': 'ไฟไม่ติด',
    'detail': 'ห้อง 101',
    'statusCode': 'NEW',
    'rowVersion': 'version',
  };

  @override
  Future<void> delete(
    int id,
    String rowVersion, {
    required bool selfService,
  }) async {
    deletedId = id;
    deletedAsSelf = selfService;
  }

  @override
  Future<void> edit(
    int id, {
    required bool selfService,
    required String subject,
    required String detail,
    required String rowVersion,
  }) async {
    editedId = id;
    editedAsSelf = selfService;
  }
}
