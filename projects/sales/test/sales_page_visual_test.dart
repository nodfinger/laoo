import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_sales/features/sales/sales_feature_host.dart';
import 'package:laoo_sales/features/sales/sales_page.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

class _FakeApi implements JsonApiClient {
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/actions/45003')) {
      return {
        'view': true,
        'create': true,
        'edit': true,
        'delete': true,
        'convert': true,
      };
    }
    if (path.endsWith('/options')) {
      return {
        'employees': <dynamic>[],
        'customers': <dynamic>[],
        'stages': [
          {'id': 1, 'code': 'NEW', 'name': 'เริ่มต้น'},
          {'id': 2, 'code': 'WON', 'name': 'ปิดการขายสำเร็จ'},
          {'id': 3, 'code': 'LOST', 'name': 'ปิดการขายไม่สำเร็จ'},
        ],
      };
    }
    if (path.endsWith('/settings')) {
      return {
        'isEnabled': true,
        'leadIdleDays': 14,
        'activityReminderDays': 2,
        'defaultStageID': 1,
        'wonStageID': 2,
        'lostStageID': 3,
      };
    }
    return [
      {
        'id': 1,
        'code': 'LEAD-260930-001',
        'name': 'บริษัท ตัวอย่างอุตสาหกรรม จำกัด',
        'type': 'ลูกค้าองค์กร',
        'status': 'NEW',
      },
      {
        'id': 2,
        'code': 'LEAD-260930-002',
        'name': 'คุณสมชาย ฝ่ายขาย',
        'type': 'ลูกค้ารายบุคคล',
        'status': 'CONTACTED',
      },
      {
        'id': 3,
        'code': 'LEAD-260930-003',
        'name': 'ห้างหุ้นส่วน ทดสอบระบบ',
        'type': 'ลูกค้าองค์กร',
        'status': 'QUALIFIED',
      },
    ];
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async => <String, dynamic>{};

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async => <String, dynamic>{};

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async => <String, dynamic>{};
}

const _tokens = LaooWorkspaceUiTokens(
  contentMargin: EdgeInsets.all(12),
  cardPadding: EdgeInsets.all(12),
  sectionSpacing: 6,
  captionFilterSpacing: 6,
  itemSpacing: 8,
  radius: 4,
  compactBreakpoint: 900,
  paginationHeight: 56,
  captionStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
  sectionStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  inputStyle: TextStyle(fontSize: 14),
  tableStyle: TextStyle(fontSize: 14),
  buttonStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  buttonHeight: 40,
  primaryColor: Color(0xFF087F5B),
  borderColor: Color(0xFFD7DEDA),
  backgroundColor: Color(0xFFF5F7F6),
);

void main() {
  setUpAll(() {
    configureSalesFeatureHost(
      ({required pageTitle, required activeMenu, required child}) => Scaffold(
        backgroundColor: _tokens.backgroundColor,
        body: SafeArea(child: child),
      ),
      apiClientFactory: _FakeApi.new,
      apiClientDisposer: (_) {},
      uiTokensProvider: () => _tokens,
      menuTitleResolver: (_, fallback) async => fallback,
      messagePresenter: (_, {required message, required error}) {},
    );
  });

  Future<void> render(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SalesPage(
          menuCode: '45003',
          title: 'ลูกค้าเป้าหมาย',
          endpoint: 'leads',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('ลูกค้าเป้าหมาย'), findsOneWidget);
    expect(find.text('LEAD-260930-001'), findsOneWidget);
  }

  testWidgets('Sales leads desktop has no overflow', (tester) async {
    await render(tester, const Size(1366, 768));
  });

  testWidgets('Sales leads mobile has no overflow', (tester) async {
    await render(tester, const Size(390, 844));
  });

  testWidgets('Sales lead popup mobile has no overflow', (tester) async {
    await render(tester, const Size(390, 844));
    await tester.tap(find.text('เพิ่ม'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('บันทึก'), findsOneWidget);
  });

  testWidgets('Sales settings ScreenType 2 mobile has no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SalesPage(
          menuCode: '45001',
          title: 'ตั้งค่าระบบขาย',
          endpoint: 'settings',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('ค่าการทำงานปัจจุบัน'), findsOneWidget);
  });
}
