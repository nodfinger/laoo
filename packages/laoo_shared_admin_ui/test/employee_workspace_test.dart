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
    required EmployeeDeleteConfirmation confirmDelete,
  }) => MaterialApp(
    home: Scaffold(
      body: EmployeeWorkspace(
        caption: 'พนักงานจากเมนู',
        repository: EmployeeRepository(api, scope: EmployeeOwnerScope.company),
        screenType: 1,
        pageSize: 20,
        companies: const [],
        organizationUnits: const [
          OrganizationUnitRecord(
            orgUnitId: 2,
            unitType: OrganizationUnitTypes.department,
            unitCode: 'SERVICE',
            nameTh: 'บริการ',
            isActive: true,
          ),
        ],
        organizationMode: 1,
        customerScope: false,
        roleGroups: const [],
        carTypes: const [],
        oilTypes: const [],
        titleBuilder: (_, title, _) => Text(title),
        messageBuilder: (_, message, error, onClose) =>
            Material(child: Text(message)),
        tokens: tokens,
        formatDate: (value) => value.toIso8601String().split('T').first,
        errorText: (error) => error.toString(),
        confirmDelete: confirmDelete,
      ),
    ),
  );

  testWidgets('coordinates list, add, cancel and confirmed delete', (
    tester,
  ) async {
    final api = _FakeApi();
    var confirmationCount = 0;
    await tester.pumpWidget(
      app(
        api: api,
        confirmDelete: (_, _) async {
          confirmationCount++;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('E001'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'เพิ่ม'));
    await tester.pumpAndSettle();
    expect(find.text('พนักงานจากเมนู > เพิ่ม'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ยกเลิก'));
    await tester.pumpAndSettle();
    expect(find.textContaining('E001'), findsOneWidget);

    await tester.tap(find.byTooltip('ลบ'));
    await tester.pumpAndSettle();
    expect(confirmationCount, 1);
    expect(api.deletedPath, '/api/company/employees/17');
    expect(find.text('ลบข้อมูลพนักงานสำเร็จ'), findsOneWidget);
  });

  testWidgets('cancelled confirmation never calls delete API', (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(
      app(api: api, confirmDelete: (_, _) async => false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('ลบ'));
    await tester.pumpAndSettle();

    expect(api.deletedPath, isNull);
  });
}

class _FakeApi implements JsonApiClient {
  String? deletedPath;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/actions')) {
      return {'view': true, 'create': true, 'edit': true, 'delete': true};
    }
    return {
      'items': [
        {
          'employeeId': 17,
          'partnerId': 3,
          'departmentOrgUnitId': 2,
          'departmentName': 'บริการ',
          'employeeCode': 'E001',
          'fullName': 'Employee One',
          'notifyInSystem': true,
          'isActive': true,
        },
      ],
      'totalCount': 1,
      'page': 1,
      'pageSize': 20,
    };
  }

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
  }) async => {'employeeId': 17};

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    deletedPath = path;
    return <String, dynamic>{};
  }
}
