import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/core/api/api_exception.dart';
import 'package:laoo_service/features/pm/data/pm_api.dart';
import 'package:laoo_service/features/pm/pages/pm_pages.dart';
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
    _FakePmApi api, {
    Size size = const Size(1100, 800),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: PmCalendarPage(api: api)));
    await tester.pumpAndSettle();
  }

  testWidgets('PM hides create and edit actions without permission', (
    tester,
  ) async {
    final api = _FakePmApi();
    await showPage(tester, api);
    expect(tester.takeException(), isNull);
    expect(find.text('สร้างงานตามรอบ'), findsNothing);
    await tester.tap(find.text('แผนทดสอบ'));
    await tester.pumpAndSettle();
    expect(find.text('เริ่มงาน'), findsNothing);
    expect(find.text('ข้ามงาน'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PM generation appears only with ScreenType 2 EDIT permission', (
    tester,
  ) async {
    final api = _FakePmApi()..canCreate = true;
    await showPage(tester, api);
    await tester.tap(find.text('สร้างงานตามรอบ'));
    await tester.pumpAndSettle();
    expect(api.generated, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PM calendar fits a narrow screen without overflow', (
    tester,
  ) async {
    final api = _FakePmApi()..canCreate = true;
    await showPage(tester, api, size: const Size(390, 700));
    expect(find.text('สร้างงานตามรอบ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portal PM schedule stays read-only with ScreenType 3', (
    tester,
  ) async {
    final api = _FakePmApi()
      ..canCreate = true
      ..canEdit = true
      ..status = 'IN_PROGRESS';
    await tester.pumpWidget(
      MaterialApp(
        home: PmCalendarPage(
          api: api,
          menuCode: '20004',
          routeName: 'portalPmSchedule',
          pageTitle: 'รอบบำรุงรักษาของห้อง',
          portalSchedule: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('สร้างงานตามรอบ'), findsNothing);
    await tester.tap(find.text('แผนทดสอบ'));
    await tester.pumpAndSettle();
    expect(find.text('บันทึกปิดงาน'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed checklist save keeps previous value and explains error', (
    tester,
  ) async {
    final api = _FakePmApi()
      ..canEdit = true
      ..status = 'IN_PROGRESS'
      ..failChecks = true;
    await showPage(tester, api);
    await tester.tap(find.text('แผนทดสอบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      false,
    );
    expect(find.textContaining('ไม่สามารถบันทึกรายการตรวจได้'), findsOneWidget);
    expect(find.textContaining('รายละเอียดเพิ่มเติม:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful PM checklist save updates the selected value', (
    tester,
  ) async {
    final api = _FakePmApi()
      ..canEdit = true
      ..status = 'IN_PROGRESS';
    await showPage(tester, api);
    await tester.tap(find.text('แผนทดสอบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      true,
    );
    expect(api.checkSaves, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PM plan popup retries a failed type lookup', (tester) async {
    final api = _FakePmApi()
      ..canCreate = true
      ..failTypesOnce = true;
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: PmPlansPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิ่มแผน PM'));
    await tester.pumpAndSettle();
    expect(find.text('ไม่สามารถโหลดประเภทอุปกรณ์ได้'), findsOneWidget);
    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(find.text('ชื่อแผน *'), findsOneWidget);
    expect(api.typeLoads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PM checklist popup explains a failed save', (tester) async {
    final api = _FakePmApi()
      ..canCreate = true
      ..failCreateChecklist = true;
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: PmChecklistsPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิ่ม Checklist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'ตรวจอุปกรณ์');
    await tester.enterText(find.byType(TextField).at(1), 'ตรวจสายไฟ');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('ไม่สามารถบันทึก Checklist ได้'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PM plans hide edit without EDIT permission', (tester) async {
    final api = _FakePmApi()..includePlan = true;
    await tester.pumpWidget(MaterialApp(home: PmPlansPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('แผนเดิม'), findsOneWidget);
    expect(find.byTooltip('แก้ไขแผน PM'), findsNothing);
    expect(find.byTooltip('ลบแผน PM'), findsNothing);
    expect(find.text('เพิ่มแผน PM'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PM checklists hide create and edit without permission', (
    tester,
  ) async {
    final api = _FakePmApi()..includeChecklist = true;
    await tester.pumpWidget(MaterialApp(home: PmChecklistsPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('รายการเดิม'), findsOneWidget);
    expect(find.text('เพิ่ม Checklist'), findsNothing);
    expect(find.byTooltip('แก้ไข Checklist'), findsNothing);
    expect(find.byTooltip('ลบ Checklist'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PM action lookup failure keeps mutation controls hidden', (
    tester,
  ) async {
    final api = _FakePmApi()
      ..includePlan = true
      ..canCreate = true
      ..canEdit = true
      ..failActions = true;
    await tester.pumpWidget(MaterialApp(home: PmPlansPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('เพิ่มแผน PM'), findsNothing);
    expect(find.byTooltip('แก้ไขแผน PM'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PM plan edit preserves identity and existing start date', (
    tester,
  ) async {
    final api = _FakePmApi()
      ..includePlan = true
      ..canEdit = true;
    await tester.pumpWidget(MaterialApp(home: PmPlansPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('แก้ไขแผน PM'));
    await tester.pumpAndSettle();
    expect(find.text('แก้ไขแผน PM'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'แผนที่แก้ไข');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(api.savedPlanId, 7);
    expect(api.savedPlanBody?['planName'], 'แผนที่แก้ไข');
    expect(api.savedPlanBody?['startDate'], '2026-09-01T00:00:00');
    expect(tester.takeException(), isNull);
  });

  testWidgets('PM checklist edit retains multiple items', (tester) async {
    final api = _FakePmApi()
      ..includeChecklist = true
      ..canEdit = true;
    await tester.pumpWidget(MaterialApp(home: PmChecklistsPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('แก้ไข Checklist'));
    await tester.pumpAndSettle();
    expect(find.text('แก้ไข Checklist'), findsOneWidget);
    expect(find.text('รายการตรวจ 2 *'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(2), 'ตรวจปลั๊กใหม่');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(api.savedChecklistId, 9);
    expect((api.savedChecklistBody?['items'] as List).length, 2);
    expect(
      (api.savedChecklistBody?['items'] as List)[1]['text'],
      'ตรวจปลั๊กใหม่',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('PM plan deletion requires DELETE and confirmation', (
    tester,
  ) async {
    final api = _FakePmApi()
      ..includePlan = true
      ..canDelete = true;
    await tester.pumpWidget(MaterialApp(home: PmPlansPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('แก้ไขแผน PM'), findsNothing);
    await tester.tap(find.byTooltip('ลบแผน PM'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ไม่สามารถเรียกคืนได้'), findsOneWidget);
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(api.deletedPlanId, isNull);
    await tester.tap(find.byTooltip('ลบแผน PM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ').last);
    await tester.pumpAndSettle();
    expect(api.deletedPlanId, 7);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PM checklist deletion requires DELETE and confirmation', (
    tester,
  ) async {
    final api = _FakePmApi()
      ..includeChecklist = true
      ..canDelete = true;
    await tester.pumpWidget(MaterialApp(home: PmChecklistsPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('แก้ไข Checklist'), findsNothing);
    await tester.tap(find.byTooltip('ลบ Checklist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ').last);
    await tester.pumpAndSettle();
    expect(api.deletedChecklistId, 9);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PM delete controls are hidden without DELETE permission', (
    tester,
  ) async {
    final api = _FakePmApi()
      ..includePlan = true
      ..includeChecklist = true
      ..canEdit = true;
    await tester.pumpWidget(MaterialApp(home: PmPlansPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('แก้ไขแผน PM'), findsOneWidget);
    expect(find.byTooltip('ลบแผน PM'), findsNothing);
    await tester.pumpWidget(MaterialApp(home: PmChecklistsPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.byTooltip('แก้ไข Checklist'), findsOneWidget);
    expect(find.byTooltip('ลบ Checklist'), findsNothing);
  });

  testWidgets('PM mutation controls are hidden for non-CRUD ScreenType', (
    tester,
  ) async {
    final api = _FakePmApi()
      ..includePlan = true
      ..screenType = 3
      ..canCreate = true
      ..canEdit = true
      ..canDelete = true;
    await tester.pumpWidget(MaterialApp(home: PmPlansPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('เพิ่มแผน PM'), findsNothing);
    expect(find.byTooltip('แก้ไขแผน PM'), findsNothing);
    expect(find.byTooltip('ลบแผน PM'), findsNothing);
  });

  for (final (label, button, page)
      in <(String, String, Widget Function(PmApi))>[
        ('แผน PM', 'เพิ่มแผน PM', (api) => PmPlansPage(api: api)),
        ('Checklist', 'เพิ่ม Checklist', (api) => PmChecklistsPage(api: api)),
      ]) {
    testWidgets('PM $label add popup fits a mobile viewport', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: page(_FakePmApi()..canCreate = true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _FakePmApi extends PmApi {
  bool canCreate = false;
  bool canEdit = false;
  bool canDelete = false;
  int screenType = 1;
  bool failChecks = false;
  bool failTypesOnce = false;
  bool failCreateChecklist = false;
  bool failActions = false;
  bool includePlan = false;
  bool includeChecklist = false;
  String status = 'PENDING';
  int generated = 0;
  int checkSaves = 0;
  int typeLoads = 0;
  int? savedPlanId;
  Map<String, dynamic>? savedPlanBody;
  int? savedChecklistId;
  int? deletedPlanId;
  int? deletedChecklistId;
  Map<String, dynamic>? savedChecklistBody;

  @override
  Future<Map<String, dynamic>> get planActions async {
    if (failActions) {
      throw const ApiException(message: 'ไม่มีสิทธิ์', statusCode: 403);
    }
    return {
      'view': true,
      'screenType': screenType,
      'create': canCreate,
      'edit': canEdit,
      'delete': canDelete,
    };
  }

  @override
  Future<Map<String, dynamic>> get checklistActions async => {
    'view': true,
    'screenType': screenType,
    'create': canCreate,
    'edit': canEdit,
    'delete': canDelete,
  };

  @override
  Future<Map<String, dynamic>> get plans async => {
    'items': includePlan
        ? [
            {
              'pmPlanId': 7,
              'planName': 'แผนเดิม',
              'itemTypeCode': 'EQUIPMENT',
              'intervalUnit': 'MONTH',
              'intervalValue': 1,
              'startDate': '2026-09-01T00:00:00',
              'isActive': true,
              'assetCount': 0,
            },
          ]
        : <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> get checklists async => {
    'items': includeChecklist
        ? [
            {
              'pmChecklistId': 9,
              'checklistName': 'รายการเดิม',
              'isActive': true,
              'itemCount': 2,
            },
          ]
        : <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> checklist(int id) async => {
    'checklist': {
      'pmChecklistId': id,
      'checklistName': 'รายการเดิม',
      'isActive': true,
    },
    'items': [
      {'checkItem': 'ตรวจสายไฟ', 'isRequired': true},
      {'checkItem': 'ตรวจปลั๊ก', 'isRequired': true},
    ],
  };

  @override
  Future<void> savePlan(Map<String, dynamic> body, {int? id}) async {
    savedPlanId = id;
    savedPlanBody = body;
  }

  @override
  Future<void> updateChecklist(int id, Map<String, dynamic> body) async {
    savedChecklistId = id;
    savedChecklistBody = body;
  }

  @override
  Future<void> deletePlan(int id) async => deletedPlanId = id;

  @override
  Future<void> deleteChecklist(int id) async => deletedChecklistId = id;

  @override
  Future<Map<String, dynamic>> get types async {
    typeLoads++;
    if (failTypesOnce && typeLoads == 1) {
      throw const ApiException(message: 'โหลดประเภทไม่ได้', statusCode: 503);
    }
    return {
      'items': [
        {'itemTypeCode': 'EQUIPMENT'},
      ],
    };
  }

  @override
  Future<void> createChecklist(Map<String, dynamic> body) async {
    if (failCreateChecklist) {
      throw const ApiException(message: 'บันทึกไม่ได้', statusCode: 503);
    }
  }

  @override
  Future<Map<String, dynamic>> workOrderActions({
    bool portalSchedule = false,
  }) async => {
    'view': true,
    'screenType': portalSchedule ? 3 : 2,
    'generate': canCreate,
    'edit': canEdit,
  };

  @override
  Future<Map<String, dynamic>> workOrders({
    String status = '',
    DateTime? from,
    DateTime? to,
    bool portalSchedule = false,
  }) async => {
    'items': [
      {
        'pmWorkOrderId': 1,
        'planNameSnapshot': 'แผนทดสอบ',
        'statusCode': this.status,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> workOrder(
    int id, {
    bool portalSchedule = false,
  }) async => {
    'workOrder': {'statusCode': status, 'planNameSnapshot': 'แผนทดสอบ'},
    'checks': [
      {
        'pmWorkOrderCheckId': 5,
        'checkItemSnapshot': 'รายการตรวจ',
        'isChecked': false,
      },
    ],
  };

  @override
  Future<void> generate({bool portalSchedule = false}) async => generated++;

  @override
  Future<void> saveChecks(
    int id,
    List<Map<String, dynamic>> items, {
    bool portalSchedule = false,
  }) async {
    checkSaves++;
    if (failChecks) {
      throw const ApiException(message: 'ไม่สามารถบันทึกได้', statusCode: 503);
    }
  }
}
