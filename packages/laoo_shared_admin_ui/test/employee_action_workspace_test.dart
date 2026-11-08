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
    bool serviceEntitled = false,
    OrganizationRepository? organizationRepository,
    Future<List<EmployeeRoleGroupOption>?> Function()? manageRoleGroups,
    Future<List<EmployeeMasterOption>?> Function()? manageCarTypes,
    Future<List<EmployeeMasterOption>?> Function()? manageOilTypes,
    List<EmployeeMasterOption> positions = const [],
    Future<List<EmployeeMasterOption>?> Function()? managePositions,
    EmployeeActionSaved? onSaved,
  }) => MaterialApp(
    home: Scaffold(
      body: EmployeeActionWorkspace(
        caption: 'พนักงานจากเมนู',
        repository: EmployeeRepository(api, scope: EmployeeOwnerScope.company),
        organizationRepository: organizationRepository,
        manageRoleGroups: manageRoleGroups,
        manageCarTypes: manageCarTypes,
        manageOilTypes: manageOilTypes,
        positions: positions,
        managePositions: managePositions,
        organizationMessageBuilder: (_, message, error, onClose) =>
            Text(message),
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
        serviceEntitled: serviceEntitled,
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

  testWidgets('selecting a position in lookup updates the combo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        api: _FakeApi(),
        positions: const [EmployeeMasterOption(code: '1', name: 'เดิม')],
        managePositions: () async => const [
          EmployeeMasterOption(code: '1', name: 'เดิม'),
          EmployeeMasterOption(code: '2', name: 'ผู้จัดการ', selected: true),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('จัดการตำแหน่ง'));
    await tester.tap(find.byTooltip('จัดการตำแหน่ง'));
    await tester.pumpAndSettle();
    expect(find.text('ผู้จัดการ'), findsOneWidget);
  });

  testWidgets('position preserves legacy value and refreshes options', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeApi();
    await tester.pumpWidget(
      app(
        api: api,
        employee: EmployeeRecord.fromJson({
          'employeeId': 17,
          'partnerId': 3,
          'departmentOrgUnitId': 2,
          'employeeCode': 'E001',
          'fullName': 'Employee One',
          'positionCode': 'Legacy Position',
          'notifyInSystem': true,
          'isActive': true,
        }),
        positions: const [
          EmployeeMasterOption(code: '00001', name: 'ผู้จัดการ'),
        ],
        managePositions: () async => const [
          EmployeeMasterOption(code: '00002', name: 'ตำแหน่งใหม่'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ข้อมูลเดิม: Legacy Position'), findsOneWidget);
    await tester.tap(find.byTooltip('จัดการตำแหน่ง'));
    await tester.pumpAndSettle();
    expect(find.text('ข้อมูลเดิม: Legacy Position'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.pumpAndSettle();
    expect((api.lastPutBody as Map)['positionCode'], 'Legacy Position');
  });

  testWidgets(
    'vehicle master management refreshes options without clearing input',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        app(
          api: _FakeApi(),
          manageCarTypes: () async => const [
            EmployeeMasterOption(code: 'NEW', name: 'รถประเภทใหม่'),
          ],
          manageOilTypes: () async => const [
            EmployeeMasterOption(code: 'NEWF', name: 'เชื้อเพลิงใหม่'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'ชื่อ-นามสกุล *'),
        'ทดสอบ',
      );
      await tester.ensureVisible(find.text('ยานพาหนะ'));
      await tester.tap(find.text('ยานพาหนะ'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('จัดการประเภทรถ').first);
      await tester.tap(find.byTooltip('จัดการประเภทรถ').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'ประเภทรถ').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('รถประเภทใหม่'), findsOneWidget);
      await tester.tap(find.text('รถประเภทใหม่'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('จัดการเชื้อเพลิง').first);
      await tester.tap(find.byTooltip('จัดการเชื้อเพลิง').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .widgetWithText(DropdownButtonFormField<String>, 'เชื้อเพลิง')
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('เชื้อเพลิงใหม่'), findsOneWidget);
      expect(find.text('ทดสอบ'), findsOneWidget);
    },
  );

  testWidgets('read only vehicle lookup keeps options and returns selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var carSearches = 0;
    var fuelSearches = 0;
    await tester.pumpWidget(
      app(
        api: _FakeApi(),
        manageCarTypes: () async {
          carSearches++;
          return const [
            EmployeeMasterOption(code: 'CAR', name: 'Car', selected: true),
          ];
        },
        manageOilTypes: () async {
          fuelSearches++;
          return const [
            EmployeeMasterOption(code: 'GAS', name: 'Gas', selected: true),
          ];
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('\u0e22\u0e32\u0e19\u0e1e\u0e32\u0e2b\u0e19\u0e30'),
    );
    await tester.tap(
      find.text('\u0e22\u0e32\u0e19\u0e1e\u0e32\u0e2b\u0e19\u0e30'),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find
          .byTooltip(
            '\u0e08\u0e31\u0e14\u0e01\u0e32\u0e23\u0e1b\u0e23\u0e30\u0e40\u0e20\u0e17\u0e23\u0e16',
          )
          .first,
    );
    await tester.tap(
      find
          .byTooltip(
            '\u0e08\u0e31\u0e14\u0e01\u0e32\u0e23\u0e1b\u0e23\u0e30\u0e40\u0e20\u0e17\u0e23\u0e16',
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Car'), findsOneWidget);
    await tester.tap(
      find
          .byTooltip(
            '\u0e08\u0e31\u0e14\u0e01\u0e32\u0e23\u0e40\u0e0a\u0e37\u0e49\u0e2d\u0e40\u0e1e\u0e25\u0e34\u0e07',
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Gas'), findsOneWidget);
    expect(carSearches, 1);
    expect(fuelSearches, 1);
  });

  testWidgets(
    'role manager refreshes options without clearing employee input',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        app(
          api: _FakeApi(),
          manageRoleGroups: () async => const [
            EmployeeRoleGroupOption(id: 5, name: 'สิทธิ์ใหม่'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'ชื่อ-นามสกุล *'),
        'ทดสอบ',
      );
      await tester.ensureVisible(find.byTooltip('จัดการกลุ่มสิทธิ์'));
      await tester.tap(find.byTooltip('จัดการกลุ่มสิทธิ์'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await tester.pumpAndSettle();
      expect(find.text('สิทธิ์ใหม่'), findsOneWidget);
      expect(find.text('ทดสอบ'), findsOneWidget);
    },
  );

  testWidgets('selected role is applied after closing the lookup', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        api: _FakeApi(),
        manageRoleGroups: () async => const [
          EmployeeRoleGroupOption(id: 5, name: 'Selected role', selected: true),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byTooltip(
        '\u0e08\u0e31\u0e14\u0e01\u0e32\u0e23\u0e01\u0e25\u0e38\u0e48\u0e21\u0e2a\u0e34\u0e17\u0e18\u0e34\u0e4c',
      ),
    );
    await tester.tap(
      find.byTooltip(
        '\u0e08\u0e31\u0e14\u0e01\u0e32\u0e23\u0e01\u0e25\u0e38\u0e48\u0e21\u0e2a\u0e34\u0e17\u0e18\u0e34\u0e4c',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Selected role'), findsOneWidget);
  });

  testWidgets('organization management is hidden without permission', (
    tester,
  ) async {
    final org = _OrganizationApi({
      'view': true,
      'create': false,
      'edit': false,
      'delete': false,
    });
    await tester.pumpWidget(
      app(
        api: _FakeApi(),
        organizationRepository: OrganizationRepository(
          org,
          scope: LaooOwnerScope.company,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('จัดการฝ่ายและแผนก'), findsNothing);
  });

  testWidgets('organization popup respects action permissions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final org = _OrganizationApi({
      'view': true,
      'create': true,
      'edit': false,
      'delete': false,
    });
    await tester.pumpWidget(
      app(
        api: _FakeApi(),
        organizationRepository: OrganizationRepository(
          org,
          scope: LaooOwnerScope.company,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('จัดการฝ่ายและแผนก'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'เพิ่มแผนก'), findsOneWidget);
    expect(find.byTooltip('แก้ไข'), findsNothing);
    expect(find.byTooltip('ลบ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('organization permission is checked again before opening', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final org = _OrganizationApi({
      'view': true,
      'create': true,
      'edit': false,
      'delete': false,
    });
    await tester.pumpWidget(
      app(
        api: _FakeApi(),
        organizationRepository: OrganizationRepository(
          org,
          scope: LaooOwnerScope.company,
        ),
      ),
    );
    await tester.pumpAndSettle();
    org.actions['create'] = false;
    await tester.tap(find.byTooltip('จัดการฝ่ายและแผนก'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('จัดการฝ่ายและแผนก'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'เพิ่มแผนก'), findsNothing);
  });

  testWidgets('desktop follows action layout and hides save by permission', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(api: _FakeApi(), canSave: false));
    await tester.pumpAndSettle();

    expect(find.text('พนักงานจากเมนู > เพิ่ม'), findsOneWidget);
    expect(find.text('สถานะ'), findsOneWidget);
    expect(find.text('ช่างซ่อม'), findsNothing);
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
        serviceEntitled: true,
        employee: EmployeeRecord.fromJson({
          'employeeId': 17,
          'partnerId': 3,
          'departmentOrgUnitId': 2,
          'employeeCode': 'E001',
          'fullName': 'Employee One',
          'notifyInSystem': true,
          'isActive': true,
          'isServiceTechnician': true,
        }),
        onSaved: (_, id) async => savedId = id,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.pumpAndSettle();

    expect(savedId, 17);
    expect(find.text('ช่างซ่อม'), findsOneWidget);
    expect((api.lastPutBody as Map)['isServiceTechnician'], true);
    expect(api.lastPutPath, '/api/company/employees/17');
  });

  testWidgets('mobile 390x844 is scrollable without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(api: _FakeApi(), serviceEntitled: true));
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('รูปพนักงาน'), findsOneWidget);
    expect(find.text('รหัสพนักงาน *'), findsOneWidget);
    expect(find.text('ช่างซ่อม'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _OrganizationApi extends _FakeApi {
  _OrganizationApi(this.actions);
  final Map<String, bool> actions;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/actions')) return actions;
    return {
      'orgStructureType': 1,
      'units': [
        {
          'orgUnitId': 2,
          'unitType': 'DEP',
          'unitCode': 'SERVICE',
          'nameTh': 'บริการ',
          'isActive': true,
        },
      ],
    };
  }
}

class _FakeApi implements JsonApiClient {
  String? lastPutPath;
  Object? lastPutBody;

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
    lastPutBody = body;
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
