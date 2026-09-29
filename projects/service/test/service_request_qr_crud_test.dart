import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/features/service_request_qr/data/service_request_qr_api.dart';
import 'package:laoo_service/features/service_request_qr/pages/service_request_qr_page.dart';
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

  Future<void> openPage(
    WidgetTester tester,
    _FakeQrApi api, {
    Size size = const Size(1100, 800),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ServiceRequestQrPage(
          api: api,
          menuName: 'จัดการ QR Code แจ้งซ่อม',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('CRUD actions follow login permissions', (tester) async {
    final api = _FakeQrApi();
    await openPage(tester, api);
    expect(find.text('เพิ่ม'), findsNothing);
    expect(find.byTooltip('แก้ไข QR Code'), findsNothing);
    expect(find.byTooltip('ลบ QR Code'), findsNothing);
    expect(find.byTooltip('แสดง QR Code'), findsOneWidget);
  });

  testWidgets('non-CRUD ScreenType hides mutations even with permissions', (
    tester,
  ) async {
    final api = _FakeQrApi()
      ..screenType = 3
      ..canCreate = true
      ..canEdit = true
      ..canDelete = true;
    await openPage(tester, api);
    expect(find.text('เพิ่ม'), findsNothing);
    expect(find.byTooltip('แก้ไข QR Code'), findsNothing);
    expect(find.byTooltip('ลบ QR Code'), findsNothing);
  });

  testWidgets('edit saves active status and reloads the row', (tester) async {
    final api = _FakeQrApi()..canEdit = true;
    await openPage(tester, api);
    await tester.tap(find.byTooltip('แก้ไข QR Code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('> แก้ไข'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(api.savedActive, false);
    expect(api.lastEditedId, 7);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete requires confirmation and removes row permanently', (
    tester,
  ) async {
    final api = _FakeQrApi()..canDelete = true;
    await openPage(tester, api);
    await tester.tap(find.byTooltip('ลบ QR Code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ไม่สามารถเรียกคืนได้'), findsOneWidget);
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(api.deletedId, isNull);
    await tester.tap(find.byTooltip('ลบ QR Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ').last);
    await tester.pumpAndSettle();
    expect(api.deletedId, 7);
    expect(find.byTooltip('ลบ QR Code'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile card keeps edit/delete available without overflow', (
    tester,
  ) async {
    final api = _FakeQrApi()
      ..canEdit = true
      ..canDelete = true;
    await openPage(tester, api, size: const Size(390, 700));
    expect(find.text('แก้ไข'), findsOneWidget);
    expect(find.text('ลบ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create shows no empty selection dialog when no assets remain', (
    tester,
  ) async {
    final api = _FakeQrApi()..canCreate = true;
    await openPage(tester, api);
    await tester.tap(find.text('เพิ่ม'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeQrApi extends ServiceRequestQrApi {
  bool canCreate = false;
  bool canEdit = false;
  bool canDelete = false;
  int screenType = 1;
  bool removed = false;
  bool active = true;
  int? deletedId;
  int? lastEditedId;
  bool? savedActive;

  @override
  Future<List<Map<String, dynamic>>> lookup({String search = ''}) async => [];

  @override
  Future<Map<String, dynamic>> actions() async => {
    'view': true,
    'screenType': screenType,
    'create': canCreate,
    'edit': canEdit,
    'delete': canDelete,
  };

  @override
  Future<Map<String, dynamic>> list({
    String search = '',
    String status = '',
    int page = 1,
  }) async => {
    'items': removed
        ? <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[
            {
              'qrPortalId': 7,
              'qrToken': 'abcdef12345678901234',
              'isActive': active,
              'itemCode': 'ITEM-1',
              'itemName': 'เครื่องทดสอบ',
              'serialNo': 'SERIAL-1',
              'locationSnapshot': 'อาคาร A / ห้อง 1',
            },
          ],
    'total': removed ? 0 : 1,
  };

  @override
  Future<void> setActive(int id, bool isActive) async {
    lastEditedId = id;
    savedActive = isActive;
    active = isActive;
  }

  @override
  Future<void> delete(int id) async {
    deletedId = id;
    removed = true;
  }
}
