import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart';

void main() {
  const owner = PartnerUserOwnerOption(
    id: 9,
    code: 'PT009',
    name: 'Partner ทดสอบ',
  );

  PartnerUserUiTokens tokens() => const PartnerUserUiTokens(
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

  Widget app({required _FakeApi api, int screenType = 1}) => MaterialApp(
    home: Scaffold(
      body: PartnerUserWorkspace(
        caption: 'Partner จากเมนู',
        repository: PartnerUserRepository(api),
        loadOwners: () async => const [owner],
        errorText: (error) => error.toString(),
        titleBuilder: (_, title, _) => Text(title),
        messageBuilder: (_, message, error, onClose) =>
            Material(child: Text(message)),
        tokens: tokens(),
        screenType: screenType,
      ),
    ),
  );

  testWidgets('shows CRUD actions from permission and opens inline form', (
    tester,
  ) async {
    final api = _FakeApi(
      actions: const {
        'view': true,
        'create': true,
        'edit': true,
        'delete': true,
      },
    );

    await tester.pumpWidget(app(api: api));
    await tester.pumpAndSettle();

    expect(find.text('Partner จากเมนู'), findsOneWidget);
    expect(find.text('partner.user'), findsOneWidget);
    expect(find.byTooltip('แก้ไข'), findsOneWidget);
    expect(find.byTooltip('ลบ'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'เพิ่ม'));
    await tester.pumpAndSettle();

    expect(find.text('Partner จากเมนู > เพิ่ม'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Username *'), findsOneWidget);
  });

  testWidgets('screen type blocks actions even when permission allows them', (
    tester,
  ) async {
    final api = _FakeApi(
      actions: const {
        'view': true,
        'create': true,
        'edit': true,
        'delete': true,
      },
    );

    await tester.pumpWidget(app(api: api, screenType: 3));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'เพิ่ม'), findsNothing);
    expect(find.byTooltip('แก้ไข'), findsNothing);
    expect(find.byTooltip('ลบ'), findsNothing);
  });

  testWidgets('mobile list and inline form do not overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeApi(
      actions: const {
        'view': true,
        'create': true,
        'edit': true,
        'delete': true,
      },
    );

    await tester.pumpWidget(app(api: api));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'เพิ่ม'));
    await tester.pumpAndSettle();

    expect(find.text('Partner จากเมนู > เพิ่ม'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeApi implements JsonApiClient {
  _FakeApi({required this.actions});

  final Map<String, bool> actions;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/actions')) return actions;
    return [
      {
        'partnerUserId': 31,
        'partnerId': 9,
        'username': 'partner.user',
        'displayName': 'ผู้ใช้ทดสอบ',
        'email': 'partner@example.com',
        'mobileNumber': '020000000',
        'isPartnerAdmin': true,
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
  }) async {}

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {}
}
