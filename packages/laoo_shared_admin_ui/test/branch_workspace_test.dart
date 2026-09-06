import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart';

void main() {
  const tokens = SharedAdminUiTokens(
    contentMargin: EdgeInsets.all(10),
    cardPadding: EdgeInsets.all(10),
    cardSpacing: 10,
    itemSpacing: 6,
    radius: 4,
    compactBreakpoint: 900,
    paginationHeight: 56,
    captionStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    ),
  );

  Widget app({
    required _FakeApi api,
    int screenType = 1,
    bool companyScope = false,
  }) => MaterialApp(
    home: Scaffold(
      body: BranchWorkspace(
        caption: 'สาขาจากเมนู',
        repository: BranchRepository(
          api,
          scope: companyScope ? LaooOwnerScope.company : LaooOwnerScope.support,
        ),
        loadCompanies: () async => const [
          BranchCompanyOption(companyId: 7, name: 'ลูกค้าทดสอบ'),
        ],
        errorText: (error) => error.toString(),
        titleBuilder: (_, title, _) => Text(title),
        messageBuilder: (_, message, error, onClose) =>
            Material(child: Text(message)),
        tokens: tokens,
        screenType: screenType,
        companyScope: companyScope,
      ),
    ),
  );

  testWidgets('uses permission actions and opens full inline form', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeApi();

    await tester.pumpWidget(app(api: api));
    await tester.pumpAndSettle();

    expect(find.text('สาขาจากเมนู'), findsOneWidget);
    expect(find.text('B001'), findsOneWidget);
    expect(find.byTooltip('แก้ไข'), findsNWidgets(20));
    expect(find.byTooltip('ลบ'), findsNWidgets(20));

    await tester.tap(find.widgetWithText(FilledButton, 'เพิ่ม'));
    await tester.pumpAndSettle();

    expect(find.text('สาขาจากเมนู > เพิ่ม'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('รหัสสาขา *'), findsOneWidget);
    expect(find.text('สถานะ'), findsOneWidget);
  });

  testWidgets('screen type blocks actions even when API allows them', (
    tester,
  ) async {
    await tester.pumpWidget(app(api: _FakeApi(), screenType: 3));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'เพิ่ม'), findsNothing);
    expect(find.byTooltip('แก้ไข'), findsNothing);
    expect(find.byTooltip('ลบ'), findsNothing);
  });

  testWidgets('pagination and mobile card layout do not overflow', (
    tester,
  ) async {
    final api = _FakeApi();
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(api: api));
    await tester.pumpAndSettle();

    expect(find.text('1-20 จาก 25'), findsOneWidget);
    await tester.tap(find.byTooltip('ถัดไป'));
    await tester.pump();
    expect(find.text('21-25 จาก 25'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsNothing);
    expect(find.textContaining('B021'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeApi implements JsonApiClient {
  final Map<String, bool> actions = const {
    'view': true,
    'create': true,
    'edit': true,
    'delete': true,
  };

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/actions')) return actions;
    return List.generate(25, (index) {
      final number = index + 1;
      return {
        'branchId': number,
        'companyId': 7,
        'companyName': 'ลูกค้าทดสอบ',
        'branchCode': 'B${number.toString().padLeft(3, '0')}',
        'branchNameTh': 'สาขาทดสอบ $number',
        'branchNameEn': null,
        'email': 'branch@example.com',
        'telephone': '020000000',
        'addressText': 'Vientiane',
        'contName': 'ผู้ติดต่อ',
        'contPhone': '020000001',
        'contPositionName': 'Manager',
        'isActive': true,
      };
    });
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {}

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {}

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {}
}
