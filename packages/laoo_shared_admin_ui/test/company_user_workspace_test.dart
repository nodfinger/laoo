import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart';

void main() {
  CompanyUserUiTokens tokens() => const CompanyUserUiTokens(
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

  Widget app({required _FakeApi api, int screenType = 2}) => MaterialApp(
    home: Scaffold(
      body: CompanyUserWorkspace(
        caption: 'ผู้ใช้งานบริษัทจากเมนู',
        repository: CompanyUserRepository(api),
        errorText: (error) => error.toString(),
        titleBuilder: (_, title, _) => Text(title),
        messageBuilder: (_, message, error, onClose) =>
            Material(child: Text(message)),
        tokens: tokens(),
        screenType: screenType,
        pageSize: 30,
      ),
    ),
  );

  testWidgets('screen type 2 exposes edit only and opens inline action', (
    tester,
  ) async {
    final api = _FakeApi();
    await tester.pumpWidget(app(api: api));
    await tester.pumpAndSettle();

    expect(find.text('ผู้ใช้งานบริษัทจากเมนู'), findsOneWidget);
    expect(find.text('customer.user'), findsOneWidget);
    expect(find.byTooltip('แก้ไข'), findsOneWidget);
    expect(find.text('เพิ่ม'), findsNothing);
    expect(find.byTooltip('ลบ'), findsNothing);

    await tester.tap(find.byTooltip('แก้ไข'));
    await tester.pumpAndSettle();

    expect(find.text('ผู้ใช้งานบริษัทจากเมนู > แก้ไข'), findsOneWidget);
    expect(find.text('สถานะ'), findsOneWidget);
    expect(find.text('Username *'), findsOneWidget);
    expect(find.text('Password ใหม่'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('view-only screen type blocks edit even when API allows it', (
    tester,
  ) async {
    final api = _FakeApi();
    await tester.pumpWidget(app(api: api, screenType: 3));
    await tester.pumpAndSettle();

    expect(find.byTooltip('แก้ไข'), findsNothing);
  });

  testWidgets('mobile list and action do not overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeApi();

    await tester.pumpWidget(app(api: api));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('แก้ไข'));
    await tester.pumpAndSettle();
    expect(find.text('ผู้ใช้งานบริษัทจากเมนู > แก้ไข'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeApi implements JsonApiClient {
  Object? lastBody;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/actions')) {
      return {'view': true, 'create': false, 'edit': true, 'delete': false};
    }
    return [
      {
        'userId': 20,
        'companyId': 12,
        'companyCode': 'C012',
        'companyName': 'ลูกค้าทดสอบ',
        'username': 'customer.user',
        'displayName': 'Customer User',
        'email': 'customer@example.com',
        'mobile': '0200000000',
        'isCompanyAdmin': false,
        'isActive': true,
      },
    ];
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
  }) async {
    lastBody = body;
  }

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {}
}
