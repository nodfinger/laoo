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
  const units = [
    OrganizationUnitRecord(
      orgUnitId: 1,
      unitType: OrganizationUnitTypes.division,
      unitCode: 'HQ',
      nameTh: 'สำนักงานใหญ่',
      isActive: true,
    ),
    OrganizationUnitRecord(
      orgUnitId: 2,
      unitType: OrganizationUnitTypes.department,
      parentOrgUnitId: 1,
      unitCode: 'SERVICE',
      nameTh: 'บริการ',
      isActive: true,
    ),
  ];

  Future<(EmployeeListController, _FakeApi)> createController({
    int screenType = 1,
  }) async {
    final api = _FakeApi();
    final controller = EmployeeListController(
      repository: EmployeeRepository(api, scope: EmployeeOwnerScope.company),
      pageSize: 20,
      screenType: screenType,
    );
    await controller.initialize();
    return (controller, api);
  }

  Widget app(
    EmployeeListController controller, {
    VoidCallback? onAdd,
    EmployeeAction? onEdit,
  }) => MaterialApp(
    home: Scaffold(
      body: EmployeeListWorkspace(
        caption: 'พนักงานจากเมนู',
        controller: controller,
        companies: const [EmployeeCompanyOption(id: 9, name: 'Customer A')],
        organizationUnits: units,
        organizationMode: 2,
        customerScope: true,
        titleBuilder: (_, title, _) => Text(title),
        tokens: tokens,
        onAdd: onAdd ?? () {},
        onEdit: onEdit ?? (_) {},
        onDelete: (_) {},
        onUser: (_) {},
      ),
    ),
  );

  testWidgets('desktop shows dynamic caption, filters and permission actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final value = await createController();
    addTearDown(value.$1.dispose);
    var added = false;
    var edited = false;

    await tester.pumpWidget(
      app(value.$1, onAdd: () => added = true, onEdit: (_) => edited = true),
    );
    await tester.pumpAndSettle();

    expect(find.text('พนักงานจากเมนู'), findsOneWidget);
    expect(find.text('E001'), findsOneWidget);
    expect(find.text('1-20 จาก 25'), findsOneWidget);
    expect(find.byTooltip('แก้ไข'), findsOneWidget);
    expect(find.byTooltip('กำหนด User'), findsOneWidget);
    expect(find.byTooltip('ลบ'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'เพิ่ม'));
    await tester.tap(find.byTooltip('แก้ไข'));
    expect(added, isTrue);
    expect(edited, isTrue);
  });

  testWidgets('search submits server filter and screen type blocks actions', (
    tester,
  ) async {
    final value = await createController(screenType: 3);
    addTearDown(value.$1.dispose);
    await tester.pumpWidget(app(value.$1));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), ' Somchai ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(value.$2.lastQuery?['search'], 'Somchai');
    expect(find.widgetWithText(FilledButton, 'เพิ่ม'), findsNothing);
    expect(find.byTooltip('แก้ไข'), findsNothing);
    expect(find.byTooltip('ลบ'), findsNothing);
  });

  testWidgets('mobile switches to cards without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final value = await createController();
    addTearDown(value.$1.dispose);

    await tester.pumpWidget(app(value.$1));
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsNothing);
    expect(find.textContaining('E001 - Employee One'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeApi implements JsonApiClient {
  Map<String, String>? lastQuery;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    lastQuery = query;
    if (path.endsWith('/actions')) {
      return {'view': true, 'create': true, 'edit': true, 'delete': true};
    }
    final requestedPage = int.tryParse(query?['page'] ?? '') ?? 1;
    return {
      'items': [
        {
          'employeeId': 17,
          'partnerId': 3,
          'companyId': 9,
          'departmentName': 'Service',
          'employeeCode': 'E001',
          'fullName': 'Employee One',
          'nickName': 'One',
          'telephone': '020000001',
          'notifyByEmail': true,
          'notifyInSystem': true,
          'isActive': true,
        },
      ],
      'totalCount': 25,
      'page': requestedPage,
      'pageSize': 20,
    };
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
