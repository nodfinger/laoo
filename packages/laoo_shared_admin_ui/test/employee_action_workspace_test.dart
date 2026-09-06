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
      orgUnitId: 2,
      unitType: OrganizationUnitTypes.department,
      unitCode: 'SERVICE',
      nameTh: 'บริการ',
      isActive: true,
    ),
  ];

  Widget app({
    required _FakeApi api,
    EmployeeRecord? employee,
    bool canSave = true,
    EmployeeActionSaved? onSaved,
  }) => MaterialApp(
    home: Scaffold(
      body: EmployeeActionWorkspace(
        caption: 'พนักงานจากเมนู',
        repository: EmployeeRepository(api, scope: EmployeeOwnerScope.company),
        employee: employee,
        companyId: null,
        customerScope: false,
        companies: const [],
        organizationUnits: units,
        organizationMode: 1,
        roleGroups: const [EmployeeRoleGroupOption(id: 4, name: 'ผู้ใช้งาน')],
        carTypes: const [EmployeeMasterOption(code: 'CAR', name: 'รถยนต์')],
        oilTypes: const [EmployeeMasterOption(code: 'GAS', name: 'เบนซิน')],
        canSave: canSave,
        titleBuilder: (_, title, _) => Text(title),
        tokens: tokens,
        formatDate: (value) => value.toIso8601String().split('T').first,
        errorText: (error) => error.toString(),
        onCancel: () {},
        onSaved: onSaved ?? (_, _) async {},
        onMessage: (_, _) {},
      ),
    ),
  );

  testWidgets('desktop follows action layout and hides save by permission', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(api: _FakeApi(), canSave: false));
    await tester.pumpAndSettle();

    expect(find.text('พนักงานจากเมนู > เพิ่ม'), findsOneWidget);
    expect(find.text('สถานะ'), findsOneWidget);
    expect(find.text('ข้อมูลพนักงาน'), findsOneWidget);
    expect(find.text('User Login'), findsOneWidget);
    expect(find.text('กรณีฉุกเฉิน'), findsOneWidget);
    expect(find.text('ยานพาหนะที่ใช้'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'บันทึก'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit saves through shared repository and callback', (
    tester,
  ) async {
    final api = _FakeApi();
    var savedId = 0;

    await tester.pumpWidget(
      app(
        api: api,
        employee: EmployeeRecord.fromJson({
          'employeeId': 17,
          'partnerId': 3,
          'departmentOrgUnitId': 2,
          'employeeCode': 'E001',
          'fullName': 'Employee One',
          'notifyInSystem': true,
          'isActive': true,
        }),
        onSaved: (_, id) async => savedId = id,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.pumpAndSettle();

    expect(savedId, 17);
    expect(api.lastPutPath, '/api/company/employees/17');
  });

  testWidgets('mobile 390x844 is scrollable without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(api: _FakeApi()));
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('รูปพนักงาน'), findsOneWidget);
    expect(find.text('รหัสพนักงาน *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeApi implements JsonApiClient {
  String? lastPutPath;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async => <String, dynamic>{};

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async => {'employeeId': 17};

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    lastPutPath = path;
    return {'employeeId': 17};
  }

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async => <String, dynamic>{};
}
